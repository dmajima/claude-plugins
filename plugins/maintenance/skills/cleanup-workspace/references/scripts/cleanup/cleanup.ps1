<#
.SYNOPSIS
    Claude Code のセッション作業領域 .claude/.local/work/ 配下の古いセッションフォルダをクリーンアップする。

.DESCRIPTION
    cleanup-workspace スキルの実装スクリプト。
    多層安全装置（パスバリデーション + シンボリックリンク保護 + 進行中セッション保護）を備える。
    実削除には -Yes フラグが必須。フラグ未指定時はドライラン相当の候補表示のみ。

.PARAMETER Days
    クリーンアップ閾値日数。最終更新がこの日数より古いセッションが対象。既定: 30

.PARAMETER Scope
    対象スコープ: global / project / both。既定: both

.PARAMETER DryRun
    ドライラン。候補表示のみで実削除なし。

.PARAMETER KeepRecent
    最新 N 件のセッションは古さ条件を満たしても保持。既定: 0

.PARAMETER IncludeTmp
    削除対象外のセッションについても workspace/tmp/ 配下を別途追加削除。

.PARAMETER Yes
    AskUserQuestion 確認をスキップして実削除を実行（呼び出し元 AI が確認済みの前提）。

.EXAMPLE
    pwsh -NoProfile -File cleanup.ps1 -Days 30 -DryRun

.EXAMPLE
    pwsh -NoProfile -File cleanup.ps1 -Days 30 -Scope global -Yes
#>

[CmdletBinding()]
param(
    [Nullable[int]]$Days = $null,

    [ValidateSet('', 'global', 'project', 'both')]
    [string]$Scope = '',

    [switch]$DryRun,

    [Nullable[int]]$KeepRecent = $null,

    [switch]$IncludeTmp,

    [switch]$Yes
)

# --- エンコーディング設定（必須） ---
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 定数 ---
$SESSION_REGEX = '^\d{8}_\d{2}_[A-Za-z0-9._\-]+$'
$CONFIG_FILE = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance\cleanup-config.json'

# --- 設定ファイル読み込み（不在時は出荷時デフォルト） ---
$config = [PSCustomObject]@{
    version                 = 1
    default_days            = 30
    default_keep_recent     = 0
    default_scope           = 'both'
    active_session_minutes  = 5
    atime_strategy          = 'progress_md'
}
if (Test-Path -LiteralPath $CONFIG_FILE) {
    try {
        $loaded = Get-Content -LiteralPath $CONFIG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($p in @($config.PSObject.Properties)) {
            $name = $p.Name
            if ($loaded.PSObject.Properties.Name -contains $name) {
                $config.$name = $loaded.$name
            }
        }
    } catch {
        Write-Warning "cleanup-config.json のパース失敗: $($_.Exception.Message). デフォルト値を使用します。"
    }
}

# --- 引数未指定時は config の既定値を採用 ---
if ($null -eq $Days)        { $Days = [int]$config.default_days }
if (-not $Scope)            { $Scope = [string]$config.default_scope }
if ($null -eq $KeepRecent)  { $KeepRecent = [int]$config.default_keep_recent }

# --- 引数組み合わせの安全装置 ---
if ($DryRun -and $Yes) {
    Write-Warning "--DryRun と --Yes を同時指定: --DryRun を優先（実削除は行いません）"
    $Yes = $false
}

# --- パスバリデーション関数 ---
# 多層検証: (1) ReparsePoint 属性確認 / (2) 名前パターン / (3) 親 3 階層の名前一致 + LinkType チェック
# (4) 想定 work/ ルートの絶対パスに対する前方一致確認（StringComparison.OrdinalIgnoreCase）
function Test-ReparsePoint {
    param($Item)
    if (-not $Item) { return $false }
    # PowerShell の LinkType は SymbolicLink / Junction / HardLink のみ報告するため、
    # ReparsePoint 属性（IO_REPARSE_TAG_* 全種別）を直接確認する
    if ($Item.LinkType) { return $true }
    try {
        $attrs = $Item.Attributes
        if (($attrs -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint) {
            return $true
        }
    } catch {}
    return $false
}

function Test-ValidSessionPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $false }

    # 絶対パスに正規化（相対パス・"." を含む経路をブロック）
    try {
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    } catch { return $false }

    $item = Get-Item -LiteralPath $resolved -Force
    # 再解析ポイント全種別を拒否（SymbolicLink / Junction / MountPoint / その他 reparse tag）
    if (Test-ReparsePoint -Item $item) { return $false }

    $name = $item.Name
    if ($name -notmatch $SESSION_REGEX) { return $false }

    # 親 3 階層も DirectoryInfo として取得し、各階層が再解析ポイントを持たないことを確認
    $parent = $item.Parent
    if ($null -eq $parent -or $parent.Name -ne 'work') { return $false }
    if (Test-ReparsePoint -Item $parent) { return $false }

    $grand = $parent.Parent
    if ($null -eq $grand -or $grand.Name -ne '.local') { return $false }
    if (Test-ReparsePoint -Item $grand) { return $false }

    $great = $grand.Parent
    if ($null -eq $great -or $great.Name -ne '.claude') { return $false }
    if (Test-ReparsePoint -Item $great) { return $false }

    # 絶対パス前方一致検証: グローバル or 現在のリポジトリの .claude/.local/work/ 配下にあること
    # $isProject も部分文字列一致ではなく、リポジトリルートからの前方一致で厳密に検証する。
    $globalRoot = Join-Path $env:USERPROFILE '.claude\.local\work'
    try { $globalResolved = (Resolve-Path -LiteralPath $globalRoot -ErrorAction Stop).Path } catch { $globalResolved = $globalRoot }
    $isGlobal = $resolved.StartsWith($globalResolved + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)

    $isProject = $false
    try {
        $tmpOut = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $tmpOut) {
            $repoRoot = $tmpOut.Trim()
            $expectedProject = Join-Path $repoRoot '.claude\.local\work'
            try { $expectedProjectResolved = (Resolve-Path -LiteralPath $expectedProject -ErrorAction Stop).Path } catch { $expectedProjectResolved = $expectedProject }
            if ($resolved.StartsWith($expectedProjectResolved + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $isProject = $true
            }
        }
    } catch {}

    if (-not ($isGlobal -or $isProject)) { return $false }

    return $true
}

# --- 対象ルート列挙 ---
$roots = @()

if ($Scope -eq 'global' -or $Scope -eq 'both') {
    $globalRoot = Join-Path $env:USERPROFILE '.claude\.local\work'
    if (Test-Path -LiteralPath $globalRoot -PathType Container) {
        $roots += [PSCustomObject]@{ Scope = 'global'; Path = (Resolve-Path -LiteralPath $globalRoot).Path }
    }
}

if ($Scope -eq 'project' -or $Scope -eq 'both') {
    $repoRoot = $null
    try {
        $tmpOut = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $tmpOut) {
            $repoRoot = $tmpOut.Trim()
        }
    } catch {}
    if (-not $repoRoot) { $repoRoot = (Get-Location).Path }

    $projectRoot = Join-Path $repoRoot '.claude\.local\work'
    if (Test-Path -LiteralPath $projectRoot -PathType Container) {
        $resolvedProject = (Resolve-Path -LiteralPath $projectRoot).Path
        if (-not ($roots.Path -contains $resolvedProject)) {
            $roots += [PSCustomObject]@{ Scope = 'project'; Path = $resolvedProject }
        }
    }
}

if ($roots.Count -eq 0) {
    Write-Output "対象ルートが見つかりませんでした（スコープ: $Scope）。"
    exit 0
}

# --- セッション列挙 + 古さ判定 + 進行中保護 ---
# atime 戦略: progress.md の最終更新時刻を「最終アクセス日時」として扱う（フォールバックは配下最大 mtime）
$nowUtc = [DateTime]::UtcNow
$threshold = $nowUtc.AddDays(-$Days)
$activeThreshold = $nowUtc.AddMinutes(-[int]$config.active_session_minutes)

$candidates = @()
$script:protectedActive = 0

foreach ($root in $roots) {
    Get-ChildItem -LiteralPath $root.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        if (-not (Test-ValidSessionPath -Path $_.FullName)) {
            Write-Verbose "Skipped (invalid): $($_.FullName)"
            return
        }
        # セッション直下のシンボリックリンクは Get-ChildItem -Directory にも入りうるためここでも除外
        if (Test-ReparsePoint -Item $_) { return }

        # 配下ファイルを 1 回だけ列挙してサイズを集計（mtime 計算は別途）
        # NOTE: -Force を付けて隠しファイルも集計対象に入れる。reparse 配下はサイズ集計上は誤差として許容。
        $files = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { -not (Test-ReparsePoint -Item $_) })
        $size = 0
        foreach ($f in $files) {
            $size += $f.Length
        }

        # atime 戦略の解決: progress.md があればその mtime、不在ならフォールバック
        $progressPath = Join-Path $_.FullName 'progress.md'
        if (Test-Path -LiteralPath $progressPath) {
            $lastAccess = (Get-Item -LiteralPath $progressPath).LastWriteTimeUtc
            # 進行中セッション保護
            if ($lastAccess -gt $activeThreshold) {
                $script:protectedActive++
                return
            }
        } else {
            # フォールバック: セッションフォルダ自身 + 配下最大 mtime
            $lastAccess = $_.LastWriteTimeUtc
            foreach ($f in $files) {
                if ($f.LastWriteTimeUtc -gt $lastAccess) { $lastAccess = $f.LastWriteTimeUtc }
            }
        }

        # 古さ判定
        if ($lastAccess -ge $threshold) { return }

        $candidates += [PSCustomObject]@{
            Scope     = $root.Scope
            Path      = $_.FullName
            Name      = $_.Name
            LastWrite = $lastAccess
            SizeBytes = $size
        }
    }
}

# --- keep-recent 適用 ---
$protectedKeepRecent = 0
if ($KeepRecent -gt 0) {
    $filtered = @()
    foreach ($scopeGroup in ($candidates | Group-Object Scope)) {
        $sorted = $scopeGroup.Group | Sort-Object LastWrite -Descending
        $kept = $sorted | Select-Object -First $KeepRecent
        $protectedKeepRecent += $kept.Count
        $filtered += $sorted | Select-Object -Skip $KeepRecent
    }
    $candidates = $filtered
}

# --- 候補表示 ---
$totalBytes = 0
foreach ($c in $candidates) { $totalBytes += $c.SizeBytes }
$totalMb = [math]::Round($totalBytes / 1MB, 2)

Write-Output ""
Write-Output "===== クリーンアップ候補 ====="
Write-Output ("スコープ:           {0}" -f $Scope)
Write-Output ("閾値日数:           {0} 日" -f $Days)
Write-Output ("keep-recent:        {0} 件" -f $KeepRecent)
Write-Output ("候補件数:           {0} 件" -f $candidates.Count)
Write-Output ("合計容量:           {0} MB" -f $totalMb)
Write-Output ("保護されたセッション:")
Write-Output ("  - 進行中:        {0} 件" -f $script:protectedActive)
Write-Output ("  - keep-recent:   {0} 件" -f $protectedKeepRecent)

if ($candidates.Count -gt 0) {
    Write-Output ""
    Write-Output "削除対象一覧:"
    foreach ($c in $candidates) {
        $mb = [math]::Round($c.SizeBytes / 1MB, 2)
        Write-Output ("  [{0}] {1}" -f $c.Scope, $c.Path)
        Write-Output ("        size={0} MB, mtime={1:yyyy-MM-dd HH:mm}" -f $mb, $c.LastWrite.ToLocalTime())
    }
}

# --- DryRun ならここで終了 ---
if ($DryRun) {
    Write-Output ""
    Write-Output "(dry-run) 実削除は行いません。"
    exit 0
}

# --- 確認後フラグ（-Yes）でない場合は確認待機状態として終了 ---
if (-not $Yes) {
    Write-Output ""
    Write-Output "実削除を行うには -Yes フラグを付けて再実行してください（AskUserQuestion 経由推奨）。"
    exit 0
}

# --- 削除実行 ---
if ($candidates.Count -eq 0) {
    Write-Output ""
    Write-Output "削除対象がありません。"
    exit 0
}

$deleted = 0
$failed = @()
$freedBytes = 0

foreach ($c in $candidates) {
    # 二重バリデーション（直前に再確認）
    if (-not (Test-ValidSessionPath -Path $c.Path)) {
        $failed += [PSCustomObject]@{ Path = $c.Path; Error = 'バリデーション失敗（再確認時）' }
        continue
    }

    try {
        Remove-Item -LiteralPath $c.Path -Recurse -Force -ErrorAction Stop
        $deleted++
        $freedBytes += $c.SizeBytes
    } catch {
        $failed += [PSCustomObject]@{ Path = $c.Path; Error = $_.Exception.Message }
    }
}

# --- IncludeTmp の追加処理 ---
$script:tmpCleared = 0
if ($IncludeTmp) {
    foreach ($root in $roots) {
        Get-ChildItem -LiteralPath $root.Path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not (Test-ValidSessionPath -Path $_.FullName)) { return }

            $tmpPath = Join-Path $_.FullName 'workspace\tmp'
            if (Test-Path -LiteralPath $tmpPath -PathType Container) {
                try {
                    Get-ChildItem -LiteralPath $tmpPath -Recurse -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                    $script:tmpCleared++
                } catch {
                    Write-Verbose "tmp clear failed: $tmpPath"
                }
            }
        }
    }
}

# --- サマリ ---
Write-Output ""
Write-Output "===== 削除結果 ====="
Write-Output ("削除完了:           {0} 件" -f $deleted)
Write-Output ("削除失敗:           {0} 件" -f $failed.Count)
Write-Output ("解放容量:           {0} MB" -f ([math]::Round($freedBytes / 1MB, 2)))
if ($IncludeTmp) {
    Write-Output ("tmp/ 掃除済み:      {0} セッション" -f $script:tmpCleared)
}

if ($failed.Count -gt 0) {
    Write-Output ""
    Write-Output "失敗一覧:"
    foreach ($f in $failed) {
        Write-Output ("  FAILED: {0}" -f $f.Path)
        Write-Output ("          {0}" -f $f.Error)
    }
    exit 2
}

exit 0
