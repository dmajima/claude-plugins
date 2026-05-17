<#
.SYNOPSIS
    cleanup-workspace スキルの閾値設定（cleanup-config.json）を表示・変更・リセットする。

.DESCRIPTION
    設定ファイルは `~/.claude/.local/plugins/maintenance/cleanup-config.json`（グローバル配下に集約）。
    cleanup.ps1 は本ファイルから既定値を読み込み、引数省略時のデフォルトとして利用する。

.PARAMETER Show
    現在の設定内容を表示する（既定動作）。

.PARAMETER SetDays
    default_days を更新する（cleanup の閾値日数）。

.PARAMETER SetKeepRecent
    default_keep_recent を更新する（最新 N 件を保持）。

.PARAMETER SetScope
    default_scope を更新する: global / project / both。

.PARAMETER SetActiveSessionMinutes
    active_session_minutes を更新する（進行中セッション保護の閾値）。

.PARAMETER Reset
    設定を出荷時デフォルトにリセットする（要 -Yes）。

.PARAMETER Yes
    破壊的操作（Reset）の確認をスキップする。

.EXAMPLE
    pwsh -NoProfile -File cleanup-config.ps1                     # 現在の設定表示
    pwsh -NoProfile -File cleanup-config.ps1 -SetDays 60         # default_days = 60 に変更
    pwsh -NoProfile -File cleanup-config.ps1 -SetScope global
    pwsh -NoProfile -File cleanup-config.ps1 -Reset -Yes
#>

[CmdletBinding()]
param(
    [switch]$Show,
    [Nullable[int]]$SetDays = $null,
    [Nullable[int]]$SetKeepRecent = $null,

    [ValidateSet('', 'global', 'project', 'both')]
    [string]$SetScope = '',

    [Nullable[int]]$SetActiveSessionMinutes = $null,
    [switch]$Reset,
    [switch]$Yes
)

# --- エンコーディング設定（必須） ---
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 定数 ---
$CONFIG_DIR = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance'
$CONFIG_FILE = Join-Path $CONFIG_DIR 'cleanup-config.json'

$DEFAULT_CONFIG = [PSCustomObject]@{
    version                 = 1
    default_days            = 30
    default_keep_recent     = 0
    default_scope           = 'both'
    active_session_minutes  = 5
    atime_strategy          = 'progress_md'
}

# --- ヘルパー関数 ---
function Get-Config {
    if (-not (Test-Path -LiteralPath $CONFIG_FILE)) {
        return $DEFAULT_CONFIG
    }
    try {
        $loaded = Get-Content -LiteralPath $CONFIG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json

        # スキーマバージョン検証（ADR-PU-012 と整合）
        $loadedVersion = if ($loaded.PSObject.Properties.Name -contains 'version') { $loaded.version } else { $null }
        if ($null -ne $loadedVersion -and $loadedVersion -ne $DEFAULT_CONFIG.version) {
            Write-Warning "[schema] cleanup-config.json の version=$loadedVersion は本スキーマ（version=$($DEFAULT_CONFIG.version)）と一致しません。出荷時デフォルトを採用します。"
            return $DEFAULT_CONFIG
        }

        # 既定値で不足フィールドを補完
        # 演算子優先順位: '-not' は '-contains' より高束縛のため、明示的に括弧でグループ化する。
        # （括弧なしだと '-not <配列>' が先評価され $false になり、補完が実質機能しない）
        foreach ($p in $DEFAULT_CONFIG.PSObject.Properties) {
            if (-not ($loaded.PSObject.Properties.Name -contains $p.Name)) {
                $loaded | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
            }
        }
        return $loaded
    } catch {
        Write-Warning "cleanup-config.json のパース失敗: $($_.Exception.Message)"
        Write-Warning "出荷時デフォルトを返します。修正後に再保存してください。"
        return $DEFAULT_CONFIG
    }
}

function Save-Config {
    param([PSCustomObject]$Config)

    try {
        if (-not (Test-Path -LiteralPath $CONFIG_DIR)) {
            New-Item -ItemType Directory -Force -Path $CONFIG_DIR -ErrorAction Stop | Out-Null
        }
        $Config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $CONFIG_FILE -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Error "cleanup-config.json の保存に失敗しました: $($_.Exception.Message)"
        exit 1
    }
}

function Format-Config {
    param([PSCustomObject]$Config)

    Write-Output "===== cleanup-workspace 閾値設定 ====="
    Write-Output "Config file: $CONFIG_FILE"
    Write-Output "Exists:      $(Test-Path -LiteralPath $CONFIG_FILE)"
    Write-Output ""
    Write-Output ("version:                 {0}" -f $Config.version)
    Write-Output ("default_days:            {0} 日" -f $Config.default_days)
    Write-Output ("default_keep_recent:     {0} 件" -f $Config.default_keep_recent)
    Write-Output ("default_scope:           {0}" -f $Config.default_scope)
    Write-Output ("active_session_minutes:  {0} 分" -f $Config.active_session_minutes)
    Write-Output ("atime_strategy:          {0}" -f $Config.atime_strategy)
}

# --- メイン処理 ---
$config = Get-Config
$modified = $false

# --- Reset 処理 ---
if ($Reset) {
    if (-not $Yes) {
        Write-Error "--Reset は破壊的です。--Yes フラグを併用してください。"
        exit 1
    }
    Save-Config -Config $DEFAULT_CONFIG
    Write-Output "===== cleanup-config.json を出荷時デフォルトにリセットしました ====="
    Format-Config -Config $DEFAULT_CONFIG
    exit 0
}

# --- 各 -Set* オプションの適用 ---
if ($null -ne $SetDays) {
    if ($SetDays -lt 0) {
        Write-Error "--SetDays は 0 以上の整数を指定してください。"
        exit 1
    }
    $config.default_days = $SetDays
    $modified = $true
    Write-Output "[updated] default_days = $SetDays"
}

if ($null -ne $SetKeepRecent) {
    if ($SetKeepRecent -lt 0) {
        Write-Error "--SetKeepRecent は 0 以上の整数を指定してください。"
        exit 1
    }
    $config.default_keep_recent = $SetKeepRecent
    $modified = $true
    Write-Output "[updated] default_keep_recent = $SetKeepRecent"
}

if ($SetScope) {
    $config.default_scope = $SetScope
    $modified = $true
    Write-Output "[updated] default_scope = $SetScope"
}

if ($null -ne $SetActiveSessionMinutes) {
    if ($SetActiveSessionMinutes -lt 1) {
        Write-Error "--SetActiveSessionMinutes は 1 以上の整数を指定してください。"
        exit 1
    }
    $config.active_session_minutes = $SetActiveSessionMinutes
    $modified = $true
    Write-Output "[updated] active_session_minutes = $SetActiveSessionMinutes"
}

# --- 保存 ---
if ($modified) {
    Save-Config -Config $config
    Write-Output ""
    Format-Config -Config $config
    exit 0
}

# --- 引数なし or --Show: 現在の設定表示のみ ---
Format-Config -Config $config
exit 0
