<#
.SYNOPSIS
    sync-settings スキルのマッピング設定（sync-mappings.json）の CRUD ヘルパー。

.DESCRIPTION
    マッピング設定ファイル `~/.claude/.local/plugins/maintenance/sync-mappings.json`（グローバル配下に集約）の読み書きを行う。
    `Get` / `Set` / `Delete` / `List` / `Show` の 5 アクションをサポート。

    スキーマ（version=2）:
    {
      "version": 2,
      "global": {
        "remote_repo": "...",
        "remote_branch": "main",
        "targets": ["settings.json", "skills", "rules", "agents", "hooks", "CLAUDE.md"],
        "last_sync_at": "ISO8601"
      },
      "projects": {
        "<absolute_path>": {
          "remote_repo": "...",
          "remote_branch": "main",
          "targets": ["..."],
          "last_sync_at": "ISO8601"
        }
      }
    }

.PARAMETER Action
    実行するアクション。get / set / delete / list / show のいずれか。

.PARAMETER Scope
    対象スコープ。global または project。get / set / delete で使用。

.PARAMETER ProjectPath
    project スコープ時の対象プロジェクトの絶対パス。省略時はカレントディレクトリのリポジトリルート（`git rev-parse --show-toplevel`、git 外なら現在のディレクトリ）を採用。

.PARAMETER Repo
    set 時の Git リモートリポジトリ URL。

.PARAMETER Branch
    set 時の Git ブランチ名。既定 main。

.PARAMETER Targets
    set 時の同期対象リスト（カンマ区切り CSV 文字列、または PowerShell の配列）。

.PARAMETER Force
    delete 時の確認スキップ。

.EXAMPLE
    pwsh -NoProfile -File sync-mappings.ps1 -Action list
    pwsh -NoProfile -File sync-mappings.ps1 -Action show
    pwsh -NoProfile -File sync-mappings.ps1 -Action get -Scope global
    pwsh -NoProfile -File sync-mappings.ps1 -Action get -Scope project
    pwsh -NoProfile -File sync-mappings.ps1 -Action set -Scope global -Repo "https://github.com/user/claude-settings" -Branch main -Targets "settings.json,skills,rules"
    pwsh -NoProfile -File sync-mappings.ps1 -Action delete -Scope project -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('get', 'set', 'delete', 'list', 'show')]
    [string]$Action,

    [ValidateSet('', 'global', 'project')]
    [string]$Scope = '',

    [string]$ProjectPath = '',

    [string]$Repo = '',

    [string]$Branch = 'main',

    [string]$Targets = '',

    [switch]$Force
)

# --- エンコーディング設定（必須） ---
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 定数 ---
$CONFIG_DIR = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance'
$CONFIG_FILE = Join-Path $CONFIG_DIR 'sync-mappings.json'

$DEFAULT_GLOBAL_TARGETS = @('settings.json', 'skills', 'rules', 'agents', 'hooks', 'CLAUDE.md')
$DEFAULT_PROJECT_TARGETS = @('.claude/settings.json', '.claude/skills', '.claude/rules', '.claude/agents', '.claude/hooks', '.claude/CLAUDE.md')

# --- ヘルパー関数 ---
function Get-MappingsStore {
    if (-not (Test-Path -LiteralPath $CONFIG_FILE)) {
        return [PSCustomObject]@{
            version  = 2
            global   = $null
            projects = [PSCustomObject]@{}
        }
    }
    try {
        $loaded = Get-Content -LiteralPath $CONFIG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
        # 演算子優先順位: '-not' を '-contains' より先に評価させないよう、明示的に括弧でグループ化する。
        if (-not ($loaded.PSObject.Properties.Name -contains 'version')) {
            $loaded | Add-Member -NotePropertyName version -NotePropertyValue 2 -Force
        }
        if (-not ($loaded.PSObject.Properties.Name -contains 'global')) {
            $loaded | Add-Member -NotePropertyName global -NotePropertyValue $null -Force
        }
        if (-not ($loaded.PSObject.Properties.Name -contains 'projects')) {
            $loaded | Add-Member -NotePropertyName projects -NotePropertyValue ([PSCustomObject]@{}) -Force
        }
        return $loaded
    } catch {
        Write-Warning "sync-mappings.json のパース失敗: $($_.Exception.Message)"
        Write-Warning "空のストアを返します。修正後に再保存してください。"
        return [PSCustomObject]@{ version = 2; global = $null; projects = [PSCustomObject]@{} }
    }
}

function Save-MappingsStore {
    param([PSCustomObject]$Store)

    if (-not (Test-Path -LiteralPath $CONFIG_DIR)) {
        New-Item -ItemType Directory -Force -Path $CONFIG_DIR | Out-Null
    }
    $Store | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $CONFIG_FILE -Encoding UTF8
}

function Resolve-ProjectPath {
    param([string]$Path)

    if ($Path) {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    }

    # カレントディレクトリのリポジトリルートを取得（git rev-parse）
    try {
        $tmp = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $tmp) {
            return $tmp.Trim()
        }
    } catch {}
    return (Get-Location).Path
}

function Format-Mapping {
    param(
        [string]$Title,
        [PSCustomObject]$Mapping
    )

    if (-not $Mapping) {
        Write-Output "  ${Title}: (未設定)"
        return
    }
    Write-Output "  ${Title}:"
    Write-Output ("    remote_repo:   {0}" -f $Mapping.remote_repo)
    Write-Output ("    remote_branch: {0}" -f $Mapping.remote_branch)
    $targetsStr = if ($Mapping.targets) { ($Mapping.targets -join ', ') } else { '(空)' }
    Write-Output ("    targets:       {0}" -f $targetsStr)
    if ($Mapping.PSObject.Properties.Name -contains 'last_sync_at' -and $Mapping.last_sync_at) {
        Write-Output ("    last_sync_at:  {0}" -f $Mapping.last_sync_at)
    }
}

function Convert-TargetsString {
    param([string]$Value)

    if (-not $Value) { return @() }
    return @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# --- アクション実装 ---
$store = Get-MappingsStore

switch ($Action) {
    'show' {
        Write-Output "===== sync-settings マッピング ====="
        Write-Output "Config file: $CONFIG_FILE"
        Write-Output "Exists:      $(Test-Path -LiteralPath $CONFIG_FILE)"
        Write-Output ("version:     {0}" -f $store.version)
        Write-Output ""
        Format-Mapping -Title 'global' -Mapping $store.global
        Write-Output ""
        $projectProps = @($store.projects.PSObject.Properties)
        if ($projectProps.Count -eq 0) {
            Write-Output "  projects: (未設定)"
        } else {
            Write-Output "  projects:"
            foreach ($p in $projectProps) {
                Write-Output ("    [{0}]" -f $p.Name)
                Format-Mapping -Title '       ' -Mapping $p.Value
            }
        }
        exit 0
    }

    'list' {
        Write-Output "===== マッピング一覧 ====="
        $count = 0
        if ($store.global) {
            Write-Output ("  [global] {0} (branch={1})" -f $store.global.remote_repo, $store.global.remote_branch)
            $count++
        }
        foreach ($p in @($store.projects.PSObject.Properties)) {
            $m = $p.Value
            Write-Output ("  [project: {0}] {1} (branch={2})" -f $p.Name, $m.remote_repo, $m.remote_branch)
            $count++
        }
        if ($count -eq 0) { Write-Output "  (マッピングなし)" }
        Write-Output ""
        Write-Output ("件数: {0} 件" -f $count)
        exit 0
    }

    'get' {
        if (-not $Scope) {
            Write-Error "-Scope が必須です（global または project）。"
            exit 1
        }
        if ($Scope -eq 'global') {
            if (-not $store.global) {
                Write-Output "(global マッピング未設定)"
                exit 0
            }
            Format-Mapping -Title 'global' -Mapping $store.global
            exit 0
        }
        # project
        $projPath = Resolve-ProjectPath -Path $ProjectPath
        if (-not ($store.projects.PSObject.Properties.Name -contains $projPath)) {
            Write-Output ("(project マッピング未設定: {0})" -f $projPath)
            exit 0
        }
        Format-Mapping -Title ("project: {0}" -f $projPath) -Mapping $store.projects.$projPath
        exit 0
    }

    'set' {
        if (-not $Scope) {
            Write-Error "-Scope が必須です（global または project）。"
            exit 1
        }
        if (-not $Repo) {
            Write-Error "-Repo が必須です（Git リモートリポジトリ URL）。"
            exit 1
        }
        # URL バリデーション
        if ($Repo -notmatch '^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:') {
            Write-Error "Repo URL の形式が無効です（https/http/git/ssh/git@host: のみ許可）: $Repo"
            exit 1
        }
        if ($Repo.StartsWith('-')) {
            Write-Error "Repo URL は '-' で始められません（git CLI のオプションとして解釈される危険があります）"
            exit 1
        }
        if ($Branch -notmatch '^[A-Za-z0-9._/\-]+$') {
            Write-Error "Branch 名に無効な文字が含まれています: $Branch"
            exit 1
        }

        $targetsArray = Convert-TargetsString -Value $Targets
        if ($targetsArray.Count -eq 0) {
            $targetsArray = if ($Scope -eq 'global') { $DEFAULT_GLOBAL_TARGETS } else { $DEFAULT_PROJECT_TARGETS }
        }

        $mapping = [PSCustomObject]@{
            remote_repo   = $Repo
            remote_branch = $Branch
            targets       = $targetsArray
            last_sync_at  = $null
        }

        if ($Scope -eq 'global') {
            $store.global = $mapping
            Write-Output "[updated] global マッピングを保存しました"
        } else {
            $projPath = Resolve-ProjectPath -Path $ProjectPath
            $store.projects | Add-Member -NotePropertyName $projPath -NotePropertyValue $mapping -Force
            Write-Output ("[updated] project マッピングを保存しました: {0}" -f $projPath)
        }

        Save-MappingsStore -Store $store
        Write-Output ""
        Format-Mapping -Title $Scope -Mapping $mapping
        exit 0
    }

    'delete' {
        if (-not $Scope) {
            Write-Error "-Scope が必須です（global または project）。"
            exit 1
        }
        if (-not $Force) {
            Write-Error "削除は破壊的です。-Force フラグを併用してください（呼び出し側で AskUserQuestion 確認後に実行）。"
            exit 1
        }
        if ($Scope -eq 'global') {
            if (-not $store.global) {
                Write-Output "(global マッピングは元々未設定でした)"
                exit 0
            }
            $store.global = $null
            Save-MappingsStore -Store $store
            Write-Output "[deleted] global マッピングを削除しました"
            exit 0
        }
        # project
        $projPath = Resolve-ProjectPath -Path $ProjectPath
        if (-not ($store.projects.PSObject.Properties.Name -contains $projPath)) {
            Write-Output ("(project マッピングは元々未設定でした: {0})" -f $projPath)
            exit 0
        }
        $store.projects.PSObject.Properties.Remove($projPath)
        Save-MappingsStore -Store $store
        Write-Output ("[deleted] project マッピングを削除しました: {0}" -f $projPath)
        exit 0
    }
}
