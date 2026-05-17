<#
.SYNOPSIS
    特定の Git リポジトリから Claude Code 設定を pull 方向のみで同期する。

.DESCRIPTION
    sync-settings スキルの実装スクリプト。
    Git clone → 差分検出 → バックアップ → 戦略別適用 の順で処理する。
    実適用には -Yes フラグが必須。フラグ未指定時は差分プレビューのみ。

.PARAMETER Repo
    同期元 Git リポジトリ URL。空指定時は sync-config.json から取得。

.PARAMETER Branch
    対象ブランチ。既定: main

.PARAMETER Targets
    同期対象のリスト。既定: settings.json, skills, rules, agents, hooks, CLAUDE.md

.PARAMETER Strategy
    同期戦略: overwrite / merge / skip。既定: overwrite

.PARAMETER DryRun
    差分表示のみで実適用なし。

.PARAMETER NoBackup
    バックアップを取得しない（非推奨、警告を表示）。

.PARAMETER Prune
    overwrite 戦略時、ローカルのみのファイルを削除。

.PARAMETER Yes
    AskUserQuestion 確認をスキップ。
#>

[CmdletBinding()]
param(
    [ValidateSet('', 'global', 'project')]
    [string]$Mapping = '',

    [string]$ProjectPath = '',

    [string]$Repo = '',

    [string]$Branch = 'main',

    [string[]]$Targets = @(),

    [ValidateSet('overwrite', 'merge', 'skip')]
    [string]$Strategy = 'overwrite',

    [switch]$DryRun,

    [switch]$NoBackup,

    [switch]$Prune,

    [switch]$Yes,

    # interactive 戦略向け: 差分一覧を JSON ファイルに出力して exit（実適用なし）
    [string]$EmitDiffJson = ''
)

# --- エンコーディング設定（必須） ---
& chcp.com 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# --- 定数 ---
$BASE_DIR = Join-Path $env:USERPROFILE '.claude\.local\plugins\maintenance'
$CONFIG_FILE = Join-Path $BASE_DIR 'sync-config.json'
$MAPPINGS_FILE = Join-Path $BASE_DIR 'sync-mappings.json'
$REPO_DIR = Join-Path $BASE_DIR 'repo'
$BACKUP_ROOT = Join-Path $BASE_DIR 'backup'
$CLAUDE_HOME = Join-Path $env:USERPROFILE '.claude'

$DEFAULT_TARGETS = @('settings.json', 'skills', 'rules', 'agents', 'hooks', 'CLAUDE.md')

# --- Mapping 解決（-Mapping 指定時のみ） ---
# -Mapping <global|project> が指定された場合、sync-mappings.json から repo / branch / targets を取得し、
# 引数で明示指定されていないフィールドのみ上書きする（引数明示は常に優先）。
if ($Mapping) {
    if (-not (Test-Path -LiteralPath $MAPPINGS_FILE)) {
        Write-Error "Mapping '$Mapping' を解決するには sync-mappings.json が必要です。/sync-map-set で設定してください。"
        exit 1
    }
    try {
        $mappingsStore = Get-Content -LiteralPath $MAPPINGS_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Error "sync-mappings.json のパース失敗: $($_.Exception.Message)"
        exit 1
    }

    $mappingEntry = $null
    if ($Mapping -eq 'global') {
        $mappingEntry = $mappingsStore.global
    } else {
        # project: ProjectPath 指定 or カレントディレクトリのリポジトリルート
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
        if ($mappingsStore.projects -and ($mappingsStore.projects.PSObject.Properties.Name -contains $resolvedProject)) {
            $mappingEntry = $mappingsStore.projects.$resolvedProject
        }
    }

    if (-not $mappingEntry) {
        Write-Error "Mapping '$Mapping' に対応するマッピングが sync-mappings.json に存在しません。/sync-map-set で設定してください。"
        exit 1
    }

    # 引数未指定のフィールドのみマッピング値で補完
    if (-not $Repo)    { $Repo = $mappingEntry.remote_repo }
    if ($Branch -eq 'main' -and $mappingEntry.remote_branch) { $Branch = $mappingEntry.remote_branch }
    if ($Targets.Count -eq 0 -and $mappingEntry.targets) { $Targets = @($mappingEntry.targets) }

    Write-Output ("[mapping] '$Mapping' から取得: repo={0}, branch={1}, targets={2} 件" -f $Repo, $Branch, $Targets.Count)

    # マッピング由来値の再検証（sync-mappings.json が外部書き換えられている可能性に備える）
    # 注: REPO_URL_REGEX / BRANCH_REGEX は定数定義より前に評価される可能性があるため、ここでは再宣言してから検証する
    $reRepo   = '^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:'
    $reBranch = '^[A-Za-z0-9._/\-]+$'
    if ($Repo -notmatch $reRepo -or $Repo.StartsWith('-')) {
        Write-Error "マッピング由来の remote_repo が無効です（外部書き換え疑い）: $Repo"
        exit 1
    }
    if ($Branch -notmatch $reBranch -or $Branch.StartsWith('-')) {
        Write-Error "マッピング由来の remote_branch が無効です（外部書き換え疑い）: $Branch"
        exit 1
    }
}

# 同期対象から常に除外（安全装置）
# credentials-management.md で列挙された認証情報系ファイル網羅 + 鍵 / 証明書 / クラウド認証
$EXCLUDE_TARGETS = @(
    # 認証情報ストア
    'credentials.json', 'credential.json', 'credentials.yml', 'credentials.yaml',
    'secrets.json', 'secret.json', 'secrets.yml', 'secrets.yaml',
    # 環境変数 / シェル系認証
    '.env', '.netrc', '.git-credentials', '.npmrc', '.pgpass', '.dockercfg',
    # ディレクトリ全体（プラグイン領域や認証ディレクトリ）
    '.local', '.git', 'plugins/cache',
    '.ssh', '.gnupg', '.aws', '.docker', '.kube'
)
$EXCLUDE_PATTERNS = @(
    # 鍵 / 証明書系
    '*.pem', '*.key', '*.pfx', '*.p12', '*.jks', '*.keystore',
    '*.crt', '*.cer', '*.der', '*.asc', '*.gpg',
    # SSH 秘密鍵（拡張子なし）
    'id_rsa', 'id_rsa.pub', 'id_dsa', 'id_dsa.pub', 'id_ecdsa', 'id_ecdsa.pub',
    'id_ed25519', 'id_ed25519.pub', 'id_xmss', 'id_xmss.pub',
    # クラウド認証ファイル
    'serviceAccountKey.json', 'service-account.json',
    'application_default_credentials.json', 'gcloud-credentials.json'
)
# .env / .env.* を正規表現で正確に判定（.env.example / .sample / .template / .dist / .test は除外しない設計）
$ENV_FILE_REGEX = '^\.env($|\.)'

# 同期元 URL の許容プロトコル
$REPO_URL_REGEX = '^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:'
# ブランチ名の許容文字（オプション注入防止: '-' 始まり禁止 / コロン禁止 / refspec 形式禁止）
$BRANCH_REGEX = '^[A-Za-z0-9._/\-]+$'
# git CLI への危険プロトコル無効化（CVE-2018-17456 系の対策）
$GIT_SAFE_OPTS = @('-c', 'protocol.file.allow=never', '-c', 'protocol.ext.allow=never')

# --- 引数組み合わせの安全装置 ---
if ($DryRun -and $Yes) {
    Write-Warning "--DryRun と --Yes を同時指定: --DryRun を優先（実適用は行いません）"
    $Yes = $false
}
if ($NoBackup -and -not $Yes) {
    Write-Verbose "--NoBackup 指定: バックアップなしで実行されます（実適用時）"
}

# --- ディレクトリ準備 ---
foreach ($d in @($BASE_DIR, $BACKUP_ROOT)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

# --- 設定ファイル読み込み ---
$config = $null
if (Test-Path -LiteralPath $CONFIG_FILE) {
    try {
        $config = Get-Content -LiteralPath $CONFIG_FILE -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "sync-config.json のパース失敗: $($_.Exception.Message)"
        $config = $null
    }
}

if (-not $Repo) {
    if ($config -and $config.last_repo) {
        $Repo = $config.last_repo
        Write-Output "Repo を設定ファイルから取得: $Repo"
    } else {
        Write-Error "Repo 引数が必要です（--Repo または sync-config.json）"
        exit 1
    }
}

if ($Targets.Count -eq 0) {
    if ($config -and $config.last_targets) {
        $Targets = @($config.last_targets)
    } else {
        $Targets = $DEFAULT_TARGETS
    }
}

# --- 除外対象が指定されていないかチェック（大小文字非感応・正規化済み） ---
# パストラバーサル '..' を含むパスは除外対象として扱う（呼び出し元で実行を中止する）。
function Test-TargetExcluded {
    param([string]$Target)

    # 正規化: バックスラッシュ → スラッシュ、先頭 ./ 除去（1 回のみ）、大小文字を小文字へ
    # NOTE: TrimStart は char[] 引数のため、'./' 全体を 1 トークンとして扱えない。
    #       先頭 './' は明示判定で除去し、その後 '/' のみ TrimStart で削除する。
    $norm = $Target.Replace('\', '/')
    if ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    $norm = $norm.TrimStart('/').ToLowerInvariant()

    # パストラバーサル拒否（先頭・中間・末尾の '..' 全パターン）
    if ($norm -match '(^|/)\.\.(/|$)') { return $true }
    # 絶対パスも拒否（C:/... や /etc/... を target に指定させない）
    if ($norm -match '^[a-z]:/' -or $norm.StartsWith('/')) { return $true }

    # 名前単位での完全一致または前方一致
    foreach ($ex in $EXCLUDE_TARGETS) {
        $exNorm = $ex.ToLowerInvariant()
        if ($norm -eq $exNorm -or $norm.StartsWith("$exNorm/")) { return $true }
    }
    # .env / .env.* の正規表現判定
    $leaf = (Split-Path -Leaf $norm)
    if ($leaf -match $ENV_FILE_REGEX) { return $true }
    # *.pem / *.key / *.pfx 等のパターン
    foreach ($pat in $EXCLUDE_PATTERNS) {
        if ($leaf -like $pat.ToLowerInvariant()) { return $true }
    }
    return $false
}

foreach ($t in $Targets) {
    if (Test-TargetExcluded -Target $t) {
        Write-Error "同期対象に除外パスが含まれています: $t"
        exit 1
    }
}

# --- Repo URL バリデーション（引数インジェクション対策） ---
if ($Repo -notmatch $REPO_URL_REGEX) {
    Write-Error "Repo URL の形式が無効です（https / http / git / ssh / git@host: のみ許可）: $Repo"
    exit 1
}
if ($Repo.StartsWith('-')) {
    Write-Error "Repo URL は '-' で始められません（git CLI のオプションとして解釈される危険があります）"
    exit 1
}

# --- Branch 名バリデーション ---
if ($Branch -notmatch $BRANCH_REGEX) {
    Write-Error "Branch 名に無効な文字が含まれています: $Branch"
    exit 1
}

# --- Git CLI 確認 ---
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Error "Git CLI が見つかりません。インストールしてください。"
    exit 1
}

# --- Git clone / reset ---
Write-Output ""
Write-Output "===== リポジトリ取得 ====="
Write-Output "Repo:   $Repo"
Write-Output "Branch: $Branch"

if (-not (Test-Path -LiteralPath $REPO_DIR)) {
    & git @GIT_SAFE_OPTS clone --depth 1 --branch $Branch -- $Repo $REPO_DIR 2>&1 | ForEach-Object { Write-Output "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git clone 失敗: exit $LASTEXITCODE"
        exit 1
    }
} else {
    Push-Location $REPO_DIR
    try {
        # 既存 repo/ の origin が想定の URL と一致するか確認（攻撃者書き換え検出）
        $currentOrigin = (& git remote get-url origin 2>$null)
        if ($LASTEXITCODE -eq 0 -and $currentOrigin) {
            $currentOrigin = $currentOrigin.Trim()
            if ($currentOrigin -ne $Repo) {
                Write-Warning "既存 repo/ の origin が期待値と異なります（期待: $Repo / 実際: $currentOrigin）。再 clone を実施します。"
                Pop-Location
                Remove-Item -LiteralPath $REPO_DIR -Recurse -Force -ErrorAction Stop
                & git @GIT_SAFE_OPTS clone --depth 1 --branch $Branch -- $Repo $REPO_DIR 2>&1 | ForEach-Object { Write-Output "  $_" }
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Git clone 失敗: exit $LASTEXITCODE"
                    exit 1
                }
                Push-Location $REPO_DIR
            }
        }
        & git @GIT_SAFE_OPTS fetch --depth 1 origin $Branch 2>&1 | ForEach-Object { Write-Output "  $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Git fetch 失敗"
            exit 1
        }
        & git @GIT_SAFE_OPTS reset --hard "origin/$Branch" 2>&1 | ForEach-Object { Write-Output "  $_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Git reset 失敗"
            exit 1
        }
        & git @GIT_SAFE_OPTS clean -fdx 2>&1 | Out-Null
    } finally {
        Pop-Location
    }
}

# 取得した commit SHA
Push-Location $REPO_DIR
$commitSha = (& git rev-parse --short HEAD 2>$null).Trim()
Pop-Location

# --- 同期対象の存在確認 ---
function Find-RemoteTarget {
    param([string]$Target)

    $cand1 = Join-Path $REPO_DIR $Target
    if (Test-Path -LiteralPath $cand1) { return $cand1 }

    $cand2 = Join-Path $REPO_DIR (Join-Path 'claude' $Target)
    if (Test-Path -LiteralPath $cand2) { return $cand2 }

    return $null
}

$resolvedTargets = @()
foreach ($t in $Targets) {
    $remote = Find-RemoteTarget -Target $t
    if ($null -eq $remote) {
        Write-Warning "同期対象 $t がリポジトリに見つかりません。スキップします。"
        continue
    }
    $resolvedTargets += [PSCustomObject]@{
        Name = $t
        Remote = $remote
        Local = Join-Path $CLAUDE_HOME $t
    }
}

# --- 差分検出 ---
function Test-FileExcluded {
    param([string]$RelativePath)

    # 正規化: バックスラッシュ → スラッシュ、先頭 ./ 除去（1 回のみ）、大小文字を小文字へ
    # NOTE: TrimStart は char[] 引数のため、'./' 全体を 1 トークンとして扱えない。
    $norm = $RelativePath.Replace('\', '/')
    if ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    $norm = $norm.TrimStart('/').ToLowerInvariant()

    # パストラバーサル拒否
    if ($norm -match '(^|/)\.\.(/|$)') { return $true }

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

function Get-FileHashSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    } catch { return $null }
}

$diffEntries = @()
foreach ($rt in $resolvedTargets) {
    if (Test-Path -LiteralPath $rt.Remote -PathType Leaf) {
        # 単一ファイル
        if (Test-FileExcluded -RelativePath $rt.Name) {
            Write-Warning "除外対象のためスキップ: $($rt.Name)"
            continue
        }
        $remoteHash = Get-FileHashSafe -Path $rt.Remote
        $localHash = Get-FileHashSafe -Path $rt.Local
        if (-not (Test-Path -LiteralPath $rt.Local)) {
            $diffEntries += [PSCustomObject]@{ Op='ADD'; Local=$rt.Local; Remote=$rt.Remote; RelPath=$rt.Name }
        } elseif ($remoteHash -ne $localHash) {
            $diffEntries += [PSCustomObject]@{ Op='MOD'; Local=$rt.Local; Remote=$rt.Remote; RelPath=$rt.Name }
        }
    } elseif (Test-Path -LiteralPath $rt.Remote -PathType Container) {
        # ディレクトリ
        Get-ChildItem -LiteralPath $rt.Remote -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($rt.Remote.Length).TrimStart('\', '/')
            $combinedRel = Join-Path $rt.Name $rel
            if (Test-FileExcluded -RelativePath $combinedRel) { return }

            $localFile = Join-Path $rt.Local $rel
            $remoteHash = Get-FileHashSafe -Path $_.FullName
            $localHash = Get-FileHashSafe -Path $localFile

            if (-not (Test-Path -LiteralPath $localFile)) {
                $diffEntries += [PSCustomObject]@{ Op='ADD'; Local=$localFile; Remote=$_.FullName; RelPath=$combinedRel }
            } elseif ($remoteHash -ne $localHash) {
                $diffEntries += [PSCustomObject]@{ Op='MOD'; Local=$localFile; Remote=$_.FullName; RelPath=$combinedRel }
            }
        }

        if ($Prune -and $Strategy -eq 'overwrite' -and (Test-Path -LiteralPath $rt.Local)) {
            Get-ChildItem -LiteralPath $rt.Local -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($rt.Local.Length).TrimStart('\', '/')
                $combinedRel = Join-Path $rt.Name $rel
                if (Test-FileExcluded -RelativePath $combinedRel) { return }

                $remoteFile = Join-Path $rt.Remote $rel
                if (-not (Test-Path -LiteralPath $remoteFile)) {
                    $diffEntries += [PSCustomObject]@{ Op='DEL'; Local=$_.FullName; Remote=$null; RelPath=$combinedRel }
                }
            }
        }
    }
}

# --- 差分表示 ---
Write-Output ""
Write-Output "===== 差分検出 ====="
Write-Output "Strategy: $Strategy"
Write-Output "件数:     $($diffEntries.Count) 件"
$addCount = ($diffEntries | Where-Object { $_.Op -eq 'ADD' }).Count
$modCount = ($diffEntries | Where-Object { $_.Op -eq 'MOD' }).Count
$delCount = ($diffEntries | Where-Object { $_.Op -eq 'DEL' }).Count
Write-Output "  [ADD] $addCount 件"
Write-Output "  [MOD] $modCount 件"
if ($Prune -and $Strategy -eq 'overwrite') {
    Write-Output "  [DEL] $delCount 件 (--prune)"
}

if ($diffEntries.Count -gt 0) {
    Write-Output ""
    foreach ($d in $diffEntries) {
        Write-Output ("  [{0}] {1}" -f $d.Op, $d.RelPath)
    }
}

# --- EmitDiffJson (interactive 戦略向け) ---
# 差分一覧を JSON ファイルに出力して終了（実適用なし）。/sync-pull の interactive 戦略で利用される。
if ($EmitDiffJson) {
    $emitDir = Split-Path -Parent $EmitDiffJson
    if ($emitDir -and -not (Test-Path -LiteralPath $emitDir)) {
        New-Item -ItemType Directory -Force -Path $emitDir | Out-Null
    }
    # PowerShell の `@() | ConvertTo-Json` は空文字列を返すため、件数 0 のときは明示的に '[]' を書く
    # 1 件のときも単一オブジェクトに展開されないよう、ConvertTo-Json -InputObject で配列を明示渡しする。
    if ($diffEntries.Count -eq 0) {
        Set-Content -LiteralPath $EmitDiffJson -Value '[]' -Encoding UTF8
    } else {
        # PowerShell 7+: -InputObject @(array) は要素数に関わらず配列として直列化される
        $jsonText = ConvertTo-Json -InputObject @($diffEntries) -Depth 10
        # PowerShell 5.1 互換性: Count=1 のときに ConvertTo-Json が単一オブジェクトを返す可能性がある場合のフェイルセーフ
        if (-not $jsonText.TrimStart().StartsWith('[')) {
            $jsonText = "[$jsonText]"
        }
        Set-Content -LiteralPath $EmitDiffJson -Value $jsonText -Encoding UTF8
    }
    Write-Output ""
    Write-Output ("[emit-diff-json] 差分一覧を JSON 出力しました: {0} ({1} 件)" -f $EmitDiffJson, $diffEntries.Count)
    exit 0
}

# --- DryRun ---
if ($DryRun) {
    Write-Output ""
    Write-Output "(dry-run) 実適用は行いません。"
    exit 0
}

if (-not $Yes) {
    Write-Output ""
    Write-Output "実適用するには -Yes フラグを付けて再実行してください（AskUserQuestion 経由推奨）。"
    exit 0
}

if ($diffEntries.Count -eq 0) {
    Write-Output ""
    Write-Output "差分がありません。同期処理をスキップします。"

    # 設定保存（last_sync_at のみ更新）
    $newConfig = [PSCustomObject]@{
        version = 1
        last_repo = $Repo
        last_branch = $Branch
        last_targets = $Targets
        last_strategy = $Strategy
        last_sync_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        history = if ($config -and $config.history) { @($config.history | Select-Object -First 9) } else { @() }
    }
    $newConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $CONFIG_FILE -Encoding UTF8
    exit 0
}

# --- バックアップ取得 ---
$backupDir = $null
if (-not $NoBackup) {
    $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
    $backupDir = Join-Path $BACKUP_ROOT $ts
    $suffix = 2
    while (Test-Path -LiteralPath $backupDir) {
        $backupDir = Join-Path $BACKUP_ROOT "${ts}_$suffix"
        $suffix++
        if ($suffix -gt 100) {
            Write-Error "バックアップディレクトリの連番が 100 を超えました。古いバックアップを削除してください。"
            exit 1
        }
    }
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

    Write-Output ""
    Write-Output "===== バックアップ ====="
    Write-Output "Backup dir: $backupDir"
    # バックアップ取得時にも除外フィルタを適用し、認証情報が backup/ に複製されないようにする。
    foreach ($t in $Targets) {
        $src = Join-Path $CLAUDE_HOME $t
        if (-not (Test-Path -LiteralPath $src)) { continue }
        if (Test-Path -LiteralPath $src -PathType Leaf) {
            # 単一ファイル: 除外フィルタを通す
            if (Test-FileExcluded -RelativePath $t) {
                Write-Warning "バックアップ除外（target）: $t"
                continue
            }
            $dst = Join-Path $backupDir $t
            $dstParent = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dstParent)) {
                New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $dst -Force
        } else {
            # ディレクトリ: 再帰的にファイル単位で除外フィルタを適用しつつコピー
            Get-ChildItem -LiteralPath $src -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                $rel = $_.FullName.Substring($src.Length).TrimStart('\', '/')
                $combinedRel = Join-Path $t $rel
                if (Test-FileExcluded -RelativePath $combinedRel) { return }
                $dst = Join-Path $backupDir $combinedRel
                $dstParent = Split-Path -Parent $dst
                if (-not (Test-Path -LiteralPath $dstParent)) {
                    New-Item -ItemType Directory -Force -Path $dstParent | Out-Null
                }
                Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
            }
        }
    }
} else {
    Write-Warning "--NoBackup 指定: バックアップを取得しません。"
}

# --- 同期適用 ---
Write-Output ""
Write-Output "===== 同期適用 ====="
$applied = 0
$failed = @()

function Merge-JsonValue {
    param($Local, $Remote)
    if ($null -eq $Local) { return $Remote }
    if ($null -eq $Remote) { return $Local }
    if ($Remote -is [array]) { return $Remote }
    if ($Remote -is [PSCustomObject]) {
        $result = [ordered]@{}
        if ($Local -is [PSCustomObject]) {
            foreach ($p in $Local.PSObject.Properties) {
                $result[$p.Name] = $p.Value
            }
        }
        foreach ($p in $Remote.PSObject.Properties) {
            if ($result.Contains($p.Name) -and $result[$p.Name] -is [PSCustomObject] -and $p.Value -is [PSCustomObject]) {
                $result[$p.Name] = Merge-JsonValue -Local $result[$p.Name] -Remote $p.Value
            } else {
                $result[$p.Name] = $p.Value
            }
        }
        return [PSCustomObject]$result
    }
    return $Remote
}

foreach ($d in $diffEntries) {
    try {
        $skipEntry = $false
        switch ($d.Op) {
            'ADD' {
                if ($Strategy -eq 'skip' -and (Test-Path -LiteralPath $d.Local)) {
                    Write-Verbose "skip 戦略: $($d.RelPath) は既存のためスキップ"
                    $skipEntry = $true
                    break
                }
                $destDir = Split-Path -Parent $d.Local
                if (-not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                }
                Copy-Item -LiteralPath $d.Remote -Destination $d.Local -Force
                $applied++
            }
            'MOD' {
                if ($Strategy -eq 'skip') {
                    Write-Verbose "skip 戦略: $($d.RelPath) はスキップ"
                    $skipEntry = $true
                    break
                }
                if ($Strategy -eq 'merge' -and ($d.RelPath -like '*settings.json' -or (Split-Path -Leaf $d.RelPath) -eq 'settings.json')) {
                    $localJson = Get-Content -LiteralPath $d.Local -Raw -Encoding UTF8 | ConvertFrom-Json
                    $remoteJson = Get-Content -LiteralPath $d.Remote -Raw -Encoding UTF8 | ConvertFrom-Json
                    $merged = Merge-JsonValue -Local $localJson -Remote $remoteJson
                    $merged | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $d.Local -Encoding UTF8
                } else {
                    Copy-Item -LiteralPath $d.Remote -Destination $d.Local -Force
                }
                $applied++
            }
            'DEL' {
                if ($Strategy -ne 'overwrite' -or -not $Prune) {
                    $skipEntry = $true
                    break
                }
                Remove-Item -LiteralPath $d.Local -Force
                $applied++
            }
        }
        if ($skipEntry) { continue }
    } catch {
        $failed += [PSCustomObject]@{ Path = $d.RelPath; Op = $d.Op; Error = $_.Exception.Message }
    }
}

# --- 設定保存 ---
$historyEntry = [PSCustomObject]@{
    sync_at = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    repo = $Repo
    branch = $Branch
    strategy = $Strategy
    commit = $commitSha
    applied = $applied
    failed = $failed.Count
}
$prevHistory = if ($config -and $config.history) { @($config.history | Select-Object -First 9) } else { @() }
$newConfig = [PSCustomObject]@{
    version = 1
    last_repo = $Repo
    last_branch = $Branch
    last_targets = $Targets
    last_strategy = $Strategy
    last_sync_at = $historyEntry.sync_at
    history = @($historyEntry) + $prevHistory
}
$newConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $CONFIG_FILE -Encoding UTF8

# --- サマリ ---
Write-Output ""
Write-Output "===== 同期結果 ====="
Write-Output "Repo:        $Repo"
Write-Output "Branch:      $Branch"
Write-Output "Commit:      $commitSha"
Write-Output "戦略:        $Strategy"
if ($backupDir) {
    Write-Output "バックアップ: $backupDir"
} else {
    Write-Output "バックアップ: なし (--NoBackup)"
}
Write-Output "適用件数:    $applied 件"
Write-Output "失敗:        $($failed.Count) 件"

if ($failed.Count -gt 0) {
    Write-Output ""
    Write-Output "失敗一覧:"
    foreach ($f in $failed) {
        Write-Output ("  FAILED [{0}] {1}" -f $f.Op, $f.Path)
        Write-Output ("          {0}" -f $f.Error)
    }
    exit 2
}

exit 0
