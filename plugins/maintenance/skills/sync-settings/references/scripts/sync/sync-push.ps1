<#
.SYNOPSIS
    sync-settings スキルの push 同期（ローカル → マッピングされたリモート repo へ commit + push）。

.DESCRIPTION
    Phase 3-D 実装。/sync-push コマンドから呼び出される。
    マッピングされたリモート Git リポジトリ（sync-mappings.json）に対し、ローカルの
    ~/.claude/ または <project>/.claude/ 配下を **push 方向** で同期する。

    フロー:
      1. sync-mappings.json から該当スコープのマッピングを取得
      2. clone 領域（~/.claude/.local/plugins/maintenance/repo/）を最新化（git fetch + reset）
      3. ローカル → repo/ にコピー（除外フィルタ適用、認証情報・Git メタデータ除外）
      4. git status で変更検出
      5. 変更があれば git add + git commit + git push（dry-run 時は git status 表示のみ）

.PARAMETER Mapping
    対象スコープ。global または project。

.PARAMETER ProjectPath
    project スコープ時の対象パス。省略時はカレントディレクトリのリポジトリルート。

.PARAMETER CommitMessage
    git commit メッセージ。既定: `sync from local <ISO8601>`

.PARAMETER DryRun
    push しない。git status / git diff --stat 相当のプレビューのみ。

.PARAMETER Yes
    AskUserQuestion 確認をスキップ（呼び出し元 AI が確認済みの前提）。

.EXAMPLE
    pwsh -NoProfile -File sync-push.ps1 -Mapping global -DryRun
    pwsh -NoProfile -File sync-push.ps1 -Mapping project -CommitMessage "update skills" -Yes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('global', 'project')]
    [string]$Mapping,

    [string]$ProjectPath = '',

    [string]$CommitMessage = '',

    [string]$BranchPrefix = 'sync-from-local',

    [string]$PrTitle = '',

    [string]$PrBody = '',

    [switch]$NoPr,

    [switch]$DryRun,

    [switch]$Yes
)

# --- エンコーディング設定 ---
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 定数 ---
$BASE_DIR = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance'
$MAPPINGS_FILE = Join-Path $BASE_DIR 'sync-mappings.json'
$REPO_DIR = Join-Path $BASE_DIR 'repo'
$CLAUDE_HOME = Join-Path $env:USERPROFILE '.claude'

# 同期対象から常に除外（push でも厳格に適用）
$EXCLUDE_TARGETS = @('credentials.json', '.env', '.local', '.git', 'plugins/cache')
$EXCLUDE_PATTERNS = @('*.pem', '*.key', '*.pfx')
$ENV_FILE_REGEX = '^\.env($|\.)'

function Test-FileExcluded {
    param([string]$RelativePath)

    $norm = $RelativePath.Replace('\', '/')
    if ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    $norm = $norm.TrimStart('/').ToLowerInvariant()

    foreach ($ex in $EXCLUDE_TARGETS) {
        $exNorm = $ex.ToLowerInvariant()
        if ($norm -eq $exNorm -or $norm.StartsWith("$exNorm/")) { return $true }
    }
    $leaf = Split-Path -Leaf $norm
    if ($leaf -match $ENV_FILE_REGEX) { return $true }
    foreach ($pat in $EXCLUDE_PATTERNS) {
        if ($leaf -like $pat.ToLowerInvariant()) { return $true }
    }
    return $false
}

# --- マッピング解決 ---
if (-not (Test-Path -LiteralPath $MAPPINGS_FILE)) {
    Write-Error "sync-mappings.json が見つかりません。/sync-map-set でマッピングを設定してください。"
    exit 1
}
try {
    $store = Get-Content -LiteralPath $MAPPINGS_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Error "sync-mappings.json のパース失敗: $($_.Exception.Message)"
    exit 1
}

$mappingEntry = $null
$localBase = ''
if ($Mapping -eq 'global') {
    $mappingEntry = $store.global
    $localBase = $CLAUDE_HOME
} else {
    $resolvedProject = $ProjectPath
    if (-not $resolvedProject) {
        try {
            $tmp = & git rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and $tmp) { $resolvedProject = $tmp.Trim() }
        } catch {}
        if (-not $resolvedProject) { $resolvedProject = (Get-Location).Path }
    } else {
        $resolvedProject = (Resolve-Path -LiteralPath $resolvedProject -ErrorAction SilentlyContinue).Path
    }
    if ($store.projects -and ($store.projects.PSObject.Properties.Name -contains $resolvedProject)) {
        $mappingEntry = $store.projects.$resolvedProject
    }
    $localBase = $resolvedProject
}

if (-not $mappingEntry) {
    Write-Error "Mapping '$Mapping' に対応するマッピングが sync-mappings.json に存在しません。/sync-map-set で設定してください。"
    exit 1
}

$repo = $mappingEntry.remote_repo
$branch = $mappingEntry.remote_branch
$targets = @($mappingEntry.targets)

Write-Output ("[mapping] {0} repo={1}, branch={2}, targets={3} 件" -f $Mapping, $repo, $branch, $targets.Count)
Write-Output ("[local-base] {0}" -f $localBase)

# --- Git CLI 確認 ---
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Error "Git CLI が見つかりません。インストールしてください。"
    exit 1
}

# --- clone 領域準備（fetch + reset） ---
Write-Output ""
Write-Output "===== リポジトリ準備 ====="
if (-not (Test-Path -LiteralPath $REPO_DIR)) {
    & git clone --branch $branch $repo $REPO_DIR 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git clone 失敗: exit $LASTEXITCODE"
        exit 1
    }
} else {
    Push-Location $REPO_DIR
    try {
        & git fetch origin $branch 2>&1 | ForEach-Object { Write-Output "  $_" }
        & git checkout $branch 2>&1 | ForEach-Object { Write-Output "  $_" }
        & git reset --hard "origin/$branch" 2>&1 | ForEach-Object { Write-Output "  $_" }
        & git clean -fdx 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

# --- ローカル → repo/ コピー ---
Write-Output ""
Write-Output "===== ローカル → repo/ コピー ====="
$copiedCount = 0
$skippedExcludedCount = 0

foreach ($t in $targets) {
    if (Test-FileExcluded -RelativePath $t) {
        Write-Warning "除外対象のためスキップ（target）: $t"
        $skippedExcludedCount++
        continue
    }
    $localTarget = Join-Path $localBase $t
    if (-not (Test-Path -LiteralPath $localTarget)) {
        Write-Warning "ローカル側に存在しないためスキップ: $localTarget"
        continue
    }

    # 単一ファイル or ディレクトリ
    if (Test-Path -LiteralPath $localTarget -PathType Leaf) {
        $destFile = Join-Path $REPO_DIR $t
        $destDir = Split-Path -Parent $destFile
        if (-not (Test-Path -LiteralPath $destDir)) {
            New-Item -ItemType Directory -Force -Path $destDir | Out-Null
        }
        Copy-Item -LiteralPath $localTarget -Destination $destFile -Force
        $copiedCount++
    } else {
        # ディレクトリ: 再帰的に各ファイルを除外フィルタ適用しつつコピー
        Get-ChildItem -LiteralPath $localTarget -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($localTarget.Length).TrimStart('\', '/')
            $combinedRel = Join-Path $t $rel
            if (Test-FileExcluded -RelativePath $combinedRel) {
                $script:skippedExcludedCount++
                return
            }
            $destFile = Join-Path $REPO_DIR $combinedRel
            $destDir = Split-Path -Parent $destFile
            if (-not (Test-Path -LiteralPath $destDir)) {
                New-Item -ItemType Directory -Force -Path $destDir | Out-Null
            }
            Copy-Item -LiteralPath $_.FullName -Destination $destFile -Force
            $script:copiedCount++
        }
    }
}

Write-Output ("コピー: {0} 件、除外スキップ: {1} 件" -f $copiedCount, $skippedExcludedCount)

# --- git status で変更検出 ---
Write-Output ""
Write-Output "===== Git 変更検出 ====="
Push-Location $REPO_DIR
try {
    $statusOutput = @(& git status --short 2>&1)
    if ($statusOutput.Count -eq 0) {
        Write-Output "(変更なし。push をスキップして終了)"
        exit 0
    }
    Write-Output ($statusOutput -join "`n")

    # --- DryRun ---
    if ($DryRun) {
        Write-Output ""
        Write-Output "(dry-run) git add / commit / push は行いません。"
        exit 0
    }

    # --- Yes フラグなしでは push しない（呼び出し元 AI が AskUserQuestion 確認済み前提） ---
    if (-not $Yes) {
        Write-Output ""
        Write-Output "実 push するには -Yes フラグを付けて再実行してください（AskUserQuestion 経由推奨）。"
        exit 0
    }

    # --- 新ブランチ作成（規定ブランチには直接 push しない、PR ベースのワークフロー） ---
    $tsBranch = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
    $newBranch = "${BranchPrefix}-${Mapping}-${tsBranch}"

    Write-Output ""
    Write-Output "===== 新ブランチ作成 + commit + push ====="
    Write-Output ("新ブランチ: {0}" -f $newBranch)

    & git checkout -b $newBranch 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "新ブランチ作成失敗: exit $LASTEXITCODE"
        exit 1
    }

    $msg = $CommitMessage
    if (-not $msg) {
        $tsCommit = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        $msg = "sync from local ${tsCommit}"
    }

    & git add -A 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git add 失敗: exit $LASTEXITCODE"
        # 規定ブランチへの復帰を試行（ベストエフォート）
        & git checkout $branch 2>&1 | Out-Null
        & git branch -D $newBranch 2>&1 | Out-Null
        exit 1
    }

    & git commit -m $msg 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git commit 失敗: exit $LASTEXITCODE"
        & git checkout $branch 2>&1 | Out-Null
        & git branch -D $newBranch 2>&1 | Out-Null
        exit 1
    }

    & git push -u origin $newBranch 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "git push 失敗: exit $LASTEXITCODE"
        & git checkout $branch 2>&1 | Out-Null
        exit 1
    }

    # --- 規定ブランチに復帰（スキル起動前と同様の状態に戻す） ---
    Write-Output ""
    Write-Output "===== 規定ブランチに復帰 ====="
    & git checkout $branch 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "規定ブランチへの復帰失敗。手動で 'git checkout $branch' を実行してください。"
    }

    # --- PR 作成（gh CLI 経由、NoPr フラグで無効化可） ---
    $prCreated = $false
    $prUrl = ''
    if ($NoPr) {
        Write-Output ""
        Write-Output "[--no-pr] PR 作成はスキップされました。"
    } else {
        Write-Output ""
        Write-Output "===== PR 作成 ====="
        $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghCmd) {
            Write-Warning "gh CLI が見つかりません。PR は作成されません。"
            Write-Output "手動で以下の PR を作成してください:"
            Write-Output ("  base:  {0}" -f $branch)
            Write-Output ("  head:  {0}" -f $newBranch)
            Write-Output ("  repo:  {0}" -f $repo)
        } else {
            $resolvedPrTitle = $PrTitle
            if (-not $resolvedPrTitle) {
                $resolvedPrTitle = "[sync-settings] $Mapping マッピングからの自動同期 ($tsBranch)"
            }
            $resolvedPrBody = $PrBody
            if (-not $resolvedPrBody) {
                $resolvedPrBody = @"
maintenance プラグインの sync-settings スキル (/sync-push) による自動同期です。

- スコープ: $Mapping
- ローカル基点: $localBase
- targets: $($targets -join ', ')
- commit: $msg
- 新ブランチ: $newBranch
- ベースブランチ: $branch

このブランチは sync-push.ps1 が作成しました。マージ後に削除してください。
"@
            }

            $ghOutput = & gh pr create --base $branch --head $newBranch --title $resolvedPrTitle --body $resolvedPrBody 2>&1
            if ($LASTEXITCODE -eq 0) {
                $prCreated = $true
                # gh pr create は URL を stdout に出す（最終行が PR URL）
                $prUrl = ($ghOutput | Select-Object -Last 1).ToString().Trim()
                Write-Output ("PR 作成成功: {0}" -f $prUrl)
            } else {
                Write-Warning "PR 作成失敗（gh CLI authentication / repo 権限を確認してください）。"
                Write-Output "手動で以下の PR を作成してください:"
                Write-Output ("  base:  {0}" -f $branch)
                Write-Output ("  head:  {0}" -f $newBranch)
                Write-Output ("  repo:  {0}" -f $repo)
                Write-Output ""
                Write-Output "gh 出力:"
                $ghOutput | ForEach-Object { Write-Output "  $_" }
            }
        }
    }

    Write-Output ""
    Write-Output "===== push 完了 ====="
    Write-Output ("Repo:        {0}" -f $repo)
    Write-Output ("Base:        {0}" -f $branch)
    Write-Output ("Head branch: {0}" -f $newBranch)
    Write-Output ("Commit:      {0}" -f $msg)
    if ($prCreated) {
        Write-Output ("PR:          {0}" -f $prUrl)
    } elseif (-not $NoPr) {
        Write-Output "PR:          (未作成・手動対応が必要)"
    }
} finally {
    Pop-Location
}

exit 0
