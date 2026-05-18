# setup_psmodule.ps1 - プラグイン専用 PowerShell モジュールキャッシュのセットアップ
# (extension-toolkit プラグイン共通、ADR-033 準拠)
#
# 使い方:
#   pwsh -NoProfile -File setup_psmodule.ps1 -ModuleName <name> [-RequiredVersion <ver>] [-TTLDays <n>] [-Force]
#
# 設計目的:
#   PSScriptAnalyzer 等の PowerShell モジュールを、ユーザのグローバル
#   ~/Documents/PowerShell/Modules/ ではなく、プラグイン専用ディレクトリ
#   ~/.claude/.local/plugins/extension-toolkit/psmodules/<name>/<version>/
#   に閉じ込めて管理する。Save-Module で任意パスにダウンロードし、呼び出し側は
#   Import-Module の絶対パス指定で利用する。
#
# ライフサイクル:
#   - キャッシュが TTL 内で有効ならスキップ（再ダウンロードなし）
#   - TTL 超過 or 未存在で Save-Module
#   - PSGallery 到達不能時のフェイルオープン: 既存キャッシュがあればそれを使う、
#     なければ status=error で終了（呼出側で skip 判断する設計）
#
# 出力:
#   - 標準出力に絶対パス（モジュールマニフェストを含むディレクトリ）1 行
#     呼出側はこのパスを Import-Module に渡す
#   - 失敗時は標準エラーにメッセージを出し、空文字行 + exit != 0
#
# 文字エンコーディング:
#   UTF-8 (no BOM) を明示設定。

param(
    [Parameter(Position = 0)]
    [string]$ModuleName = 'PSScriptAnalyzer',

    [Parameter(Position = 1)]
    [string]$RequiredVersion = '1.22.0',

    [Parameter(Position = 2)]
    [int]$TTLDays = 30,

    [switch]$Force,

    # 指定時、結果（{ status, path, version, cache_marker }）を JSON でこのパスに書き出す。
    # 呼出側はこのファイルを読むことで Write-Host 混入なしに結果を確実に受け取れる
    # （呼出側互換のため、stdout への Write-Output によるパス出力も維持する）
    [string]$OutputJson = ''
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

# --- 入力検証 ---------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($ModuleName)) {
    [Console]::Error.WriteLine('[setup_psmodule] Error: -ModuleName is required')
    exit 1
}

# モジュール名・バージョン名はディレクトリ名に展開されるため、
# パストラバーサル防御として安全な文字種のみ許可
if ($ModuleName -notmatch '^[A-Za-z][A-Za-z0-9_.-]*$') {
    [Console]::Error.WriteLine("[setup_psmodule] Error: invalid module name: $ModuleName")
    exit 1
}
if (-not [string]::IsNullOrWhiteSpace($RequiredVersion) `
    -and $RequiredVersion -notmatch '^[0-9]+(\.[0-9]+){0,3}([-+][A-Za-z0-9.]+)?$') {
    [Console]::Error.WriteLine("[setup_psmodule] Error: invalid version: $RequiredVersion")
    exit 1
}
if ($TTLDays -lt 0 -or $TTLDays -gt 3650) {
    [Console]::Error.WriteLine("[setup_psmodule] Error: TTLDays out of range (0..3650): $TTLDays")
    exit 1
}

# --- キャッシュベースディレクトリの決定 -------------------------------------
# local-data-directory.md ルール:
#   1. リポジトリ配下 (.git を含む祖先) → {repo_root}/.claude/.local/plugins/extension-toolkit/psmodules/
#   2. リポジトリ外 → ~/.claude/.local/plugins/extension-toolkit/psmodules/

function Find-RepoRoot {
    $cur = (Get-Location).Path
    while ($cur -and (Test-Path -LiteralPath $cur)) {
        if (Test-Path -LiteralPath (Join-Path $cur '.git')) {
            return $cur
        }
        $parent = Split-Path -Parent $cur
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $cur) { break }
        $cur = $parent
    }
    return $null
}

$repoRoot = Find-RepoRoot
if ($repoRoot) {
    $baseDir = Join-Path $repoRoot '.claude/.local/plugins/extension-toolkit/psmodules'
} else {
    $homeDir = [Environment]::GetFolderPath('UserProfile')
    $baseDir = Join-Path $homeDir '.claude/.local/plugins/extension-toolkit/psmodules'
}

$baseDir = [System.IO.Path]::GetFullPath($baseDir)
$moduleBase = Join-Path $baseDir $ModuleName

# 安全装置: baseDir が必ず .claude/.local/plugins/extension-toolkit/psmodules で終わる
$normalizedBase = $baseDir -replace '\\', '/'
if ($normalizedBase -notmatch '/\.claude/\.local/plugins/extension-toolkit/psmodules$') {
    [Console]::Error.WriteLine("[setup_psmodule] Error: resolved base dir does not match expected pattern: $baseDir")
    exit 1
}

# --- 既存キャッシュ検出 -----------------------------------------------------

function Get-CachedModulePath {
    param(
        [string]$ModuleBase,
        [string]$Version
    )
    if (-not (Test-Path -LiteralPath $ModuleBase -PathType Container)) {
        return $null
    }
    # PSGallery の Save-Module は <ModuleBase>/<Version>/<ModuleName>.psd1 を作る
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        $candidate = Join-Path $ModuleBase $Version
        $manifest = Join-Path $candidate "$ModuleName.psd1"
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            return $candidate
        }
        return $null
    }
    # バージョン未指定なら最新のディレクトリを返す
    $latest = Get-ChildItem -LiteralPath $ModuleBase -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^[0-9]+(\.[0-9]+){0,3}' } |
        Sort-Object { [System.Version]($_.Name -replace '[-+].*$', '') } -Descending |
        Select-Object -First 1
    if ($latest) {
        $manifest = Join-Path $latest.FullName "$ModuleName.psd1"
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            return $latest.FullName
        }
    }
    return $null
}

function Test-CacheFresh {
    param(
        [string]$ModulePath,
        [int]$TTLDays
    )
    if (-not $ModulePath -or -not (Test-Path -LiteralPath $ModulePath)) {
        return $false
    }
    if ($TTLDays -le 0) {
        return $true  # TTL 無期限
    }
    $marker = Join-Path $ModulePath '.cache-marker'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
        # marker 不在は古いキャッシュとみなす
        return $false
    }
    try {
        $mtime = (Get-Item -LiteralPath $marker).LastWriteTime
        $age = (Get-Date) - $mtime
        return $age.TotalDays -lt $TTLDays
    } catch {
        return $false
    }
}

function Write-OutputJson {
    param(
        [string]$Path,
        [hashtable]$Data
    )
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    try {
        $Data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding utf8
    } catch {
        [Console]::Error.WriteLine("[setup_psmodule] Warning: failed to write OutputJson: $($_.Exception.Message)")
    }
}

$cachedPath = Get-CachedModulePath -ModuleBase $moduleBase -Version $RequiredVersion
$cacheFresh = (-not $Force) -and (Test-CacheFresh -ModulePath $cachedPath -TTLDays $TTLDays)

if ($cacheFresh) {
    Write-Host "[setup_psmodule] Cache HIT: $cachedPath (TTL=$TTLDays days)"
    Write-OutputJson -Path $OutputJson -Data @{
        status        = 'cache_hit'
        path          = $cachedPath
        version       = $RequiredVersion
        module        = $ModuleName
    }
    Write-Output $cachedPath
    exit 0
}

# --- Save-Module 実行 -------------------------------------------------------

New-Item -ItemType Directory -Force -Path $moduleBase | Out-Null

$saveArgs = @{
    Name        = $ModuleName
    Path        = $baseDir
    Force       = $true
    ErrorAction = 'Stop'
}
if (-not [string]::IsNullOrWhiteSpace($RequiredVersion)) {
    $saveArgs.RequiredVersion = $RequiredVersion
}

Write-Host "[setup_psmodule] Downloading $ModuleName $RequiredVersion via Save-Module to $baseDir"

$saveOk = $false
try {
    Save-Module @saveArgs
    $saveOk = $true
} catch {
    [Console]::Error.WriteLine("[setup_psmodule] Save-Module failed: $($_.Exception.GetType().Name)")
    # フェイルオープン: 既存キャッシュがあればそれを使う
}

if ($saveOk) {
    $resolved = Get-CachedModulePath -ModuleBase $moduleBase -Version $RequiredVersion
    if (-not $resolved) {
        [Console]::Error.WriteLine("[setup_psmodule] Error: Save-Module reported success but module not found at $moduleBase")
        Write-OutputJson -Path $OutputJson -Data @{
            status  = 'error'
            reason  = 'save_succeeded_but_not_found'
            path    = ''
            version = $RequiredVersion
            module  = $ModuleName
        }
        exit 2
    }
    # cache marker 更新
    $marker = Join-Path $resolved '.cache-marker'
    Set-Content -LiteralPath $marker -Value (Get-Date -Format 'o') -Encoding utf8
    Write-Host "[setup_psmodule] Cache REFRESHED: $resolved"
    Write-OutputJson -Path $OutputJson -Data @{
        status  = 'refreshed'
        path    = $resolved
        version = $RequiredVersion
        module  = $ModuleName
    }
    Write-Output $resolved
    exit 0
}

# フェイルオープン経路: Save-Module 失敗だが既存キャッシュが残っていれば再利用
$fallback = Get-CachedModulePath -ModuleBase $moduleBase -Version $RequiredVersion
if (-not $fallback) {
    $fallback = Get-CachedModulePath -ModuleBase $moduleBase -Version ''
}
if ($fallback) {
    Write-Host "[setup_psmodule] Save-Module failed but existing cache reused: $fallback"
    Write-OutputJson -Path $OutputJson -Data @{
        status  = 'fallback_cache'
        path    = $fallback
        version = $RequiredVersion
        module  = $ModuleName
    }
    Write-Output $fallback
    exit 0
}

[Console]::Error.WriteLine("[setup_psmodule] Error: no cache available and Save-Module failed")
Write-OutputJson -Path $OutputJson -Data @{
    status  = 'unavailable'
    reason  = 'no_cache_and_save_failed'
    path    = ''
    version = $RequiredVersion
    module  = $ModuleName
}
Write-Output ''
exit 3
