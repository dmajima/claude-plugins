<#
.SYNOPSIS
    sync-settings スキルの pull / push スクリプト共通ライブラリ（dot-source 用）。

.DESCRIPTION
    sync.ps1 / sync-push.ps1 で重複していた以下を SSOT として集約する:
    - 認証情報除外リスト（EXCLUDE_TARGETS / EXCLUDE_PATTERNS / ENV_FILE_REGEX）
    - 入力バリデーション正規表現（REPO_URL_REGEX / BRANCH_REGEX）
    - git CLI 安全オプション（GIT_SAFE_OPTS）
    - Test-TargetExcluded / Test-FileExcluded / Test-ReparseItem / Hide-SecretsInLine 関数

    呼び出し側は以下のように dot-source して使う:

        . (Join-Path $PSScriptRoot 'sync-common.ps1')

    認証情報パターンや除外リストの追加は本ファイルのみで完結し、
    pull/push 両経路へ自動的に反映される（Cycle 2 アーキレビュー H-arch-1 への対応）。

.NOTES
    本ファイルは dot-source 専用であり、独立に実行されることは想定していない。
    エンコーディングは UTF-8 / BOM なし固定。
#>

# --- 認証情報除外（pull / push 共通 SSOT） ---
# credentials-management.md で列挙された認証情報系ファイル網羅 + 鍵 / 証明書 / クラウド認証
$script:EXCLUDE_TARGETS = @(
    # 認証情報ストア
    'credentials.json', 'credential.json', 'credentials.yml', 'credentials.yaml',
    'secrets.json', 'secret.json', 'secrets.yml', 'secrets.yaml',
    # 環境変数 / シェル系認証
    '.env', '.netrc', '.git-credentials', '.npmrc', '.pgpass', '.dockercfg',
    # ディレクトリ全体（プラグイン領域や認証ディレクトリ）
    '.local', '.git', 'plugins/cache',
    '.ssh', '.gnupg', '.aws', '.docker', '.kube'
)
$script:EXCLUDE_PATTERNS = @(
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
$script:ENV_FILE_REGEX = '^\.env($|\.)'

# --- 入力バリデーション正規表現 ---
# Repo URL: https / http / git / ssh / git@host:
$script:REPO_URL_REGEX = '^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:'
# Branch 名: 英数字 / . / _ / / / - のみ。'..' を含む refspec の偽装は別途明示拒否
$script:BRANCH_REGEX = '^[A-Za-z0-9._/\-]+$'
# BranchPrefix: '/' を含まない安全形（push 用ブランチ名構築要素）
$script:BRANCH_PREFIX_REGEX = '^[A-Za-z0-9._\-]+$'

# --- git CLI 安全オプション（CVE-2018-17456 系の対策） ---
$script:GIT_SAFE_OPTS = @('-c', 'protocol.file.allow=never', '-c', 'protocol.ext.allow=never')

# --- 認証情報の二次マスク（ログ出力時のパターン伏字化） ---
$script:SECRET_PATTERNS = @(
    'sk-[A-Za-z0-9]{16,}',
    'ghp_[A-Za-z0-9]{20,}',
    'gho_[A-Za-z0-9]{20,}',
    'ghu_[A-Za-z0-9]{20,}',
    'ghs_[A-Za-z0-9]{20,}',
    'ghr_[A-Za-z0-9]{20,}',
    'xox[bpars]-[A-Za-z0-9\-]{10,}',
    'AKIA[A-Z0-9]{16}',
    'AIza[A-Za-z0-9_\-]{35}',
    'glpat-[A-Za-z0-9_\-]{20,}',
    'Bearer\s+[A-Za-z0-9\._\-]{16,}',
    # Repo URL に埋め込まれた user:token@host 形式
    'https?://[^@/\s]+:[^@/\s]+@'
)

function Hide-SecretsInLine {
    [CmdletBinding()]
    param([string]$Line)
    if (-not $Line) { return $Line }
    $masked = $Line
    foreach ($pat in $script:SECRET_PATTERNS) {
        $masked = [regex]::Replace($masked, $pat, '[REDACTED]')
    }
    return $masked
}

function Write-MaskedOutput {
    [CmdletBinding()]
    param([string]$Line)
    Write-Output ("  " + (Hide-SecretsInLine $Line))
}

# --- 再解析ポイント検査（symlink / junction / mountpoint / 他 reparse tag を拒否） ---
function Test-ReparseItem {
    [CmdletBinding()]
    param($Item)
    if (-not $Item) { return $false }
    # PowerShell の LinkType は SymbolicLink / Junction / HardLink のみ報告するため、
    # ReparsePoint 属性（IO_REPARSE_TAG_* 全種別）も直接確認する
    if ($Item.LinkType) { return $true }
    try {
        $attrs = $Item.Attributes
        if (($attrs -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint) {
            return $true
        }
    } catch {}
    return $false
}

# --- 除外判定（target レベル: ユーザ指定の対象パス） ---
# パストラバーサル '..' / 絶対パス / NUL バイトを含むパスは除外対象として扱う
function Test-TargetExcluded {
    [CmdletBinding()]
    param([string]$Target)

    if (-not $Target) { return $true }
    # NUL バイトを含む文字列は安全策で拒否
    if ($Target -match "\x00") { return $true }

    # 正規化: バックスラッシュ → スラッシュ、先頭 ./ 除去、大小文字を小文字へ
    $norm = $Target.Replace('\', '/')
    if ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    $norm = $norm.TrimStart('/').ToLowerInvariant()

    # パストラバーサル拒否
    if ($norm -match '(^|/)\.\.(/|$)') { return $true }
    # 絶対パス拒否（C:/... or /etc/...）
    if ($norm -match '^[a-z]:/' -or $norm.StartsWith('/')) { return $true }

    foreach ($ex in $script:EXCLUDE_TARGETS) {
        $exNorm = $ex.ToLowerInvariant()
        if ($norm -eq $exNorm -or $norm.StartsWith("$exNorm/")) { return $true }
    }
    $leaf = Split-Path -Leaf $norm
    if ($leaf -match $script:ENV_FILE_REGEX) { return $true }
    foreach ($pat in $script:EXCLUDE_PATTERNS) {
        if ($leaf -like $pat.ToLowerInvariant()) { return $true }
    }
    return $false
}

# --- 除外判定（ファイルレベル: 個別ファイルの相対パス） ---
function Test-FileExcluded {
    [CmdletBinding()]
    param([string]$RelativePath)

    if (-not $RelativePath) { return $true }
    if ($RelativePath -match "\x00") { return $true }

    $norm = $RelativePath.Replace('\', '/')
    if ($norm.StartsWith('./')) { $norm = $norm.Substring(2) }
    $norm = $norm.TrimStart('/').ToLowerInvariant()

    # パストラバーサル拒否
    if ($norm -match '(^|/)\.\.(/|$)') { return $true }

    foreach ($ex in $script:EXCLUDE_TARGETS) {
        $exNorm = $ex.ToLowerInvariant()
        if ($norm -eq $exNorm -or $norm.StartsWith("$exNorm/")) { return $true }
    }
    $leaf = Split-Path -Leaf $norm
    if ($leaf -match $script:ENV_FILE_REGEX) { return $true }
    foreach ($pat in $script:EXCLUDE_PATTERNS) {
        if ($leaf -like $pat.ToLowerInvariant()) { return $true }
    }
    return $false
}

# --- 再帰列挙: reparse point の追従を抑制した安全な Get-ChildItem ラッパー ---
# Get-ChildItem -Recurse はシンボリックリンク / ジャンクションを辿るため、
# 攻撃者が仕込んだ symlink 経由でローカルの認証情報（~/.ssh/id_rsa 等）が
# 同期対象に流れ込むリスクがある。本関数は各階層で再解析ポイントを検出した
# 時点で配下のスキャンを停止する自前再帰を行う。
function Get-NonReparseFileItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [int]$MaxDepth = 32
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return }

    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue
    if (-not $rootItem -or (Test-ReparseItem -Item $rootItem)) { return }

    $stack = New-Object System.Collections.Stack
    $stack.Push([PSCustomObject]@{ Path = $Root; Depth = 0 })

    while ($stack.Count -gt 0) {
        $entry = $stack.Pop()
        if ($entry.Depth -ge $MaxDepth) { continue }

        $children = $null
        try {
            $children = Get-ChildItem -LiteralPath $entry.Path -Force -ErrorAction SilentlyContinue
        } catch {
            continue
        }
        if (-not $children) { continue }

        foreach ($c in $children) {
            # symlink / junction / reparse point はすべてスキップ（フォロー禁止）
            if (Test-ReparseItem -Item $c) { continue }
            if ($c.PSIsContainer) {
                $stack.Push([PSCustomObject]@{ Path = $c.FullName; Depth = $entry.Depth + 1 })
            } else {
                # 出力は FileInfo 相当
                $c
            }
        }
    }
}

# --- 安全な引数文字列検証（呼び出し元から共通利用） ---
# Branch 名の追加チェック: '..' を含む / '/' で始まる・終わる場合を拒否
function Test-BranchNameSafe {
    [CmdletBinding()]
    param([string]$Branch)
    if (-not $Branch) { return $false }
    if ($Branch -notmatch $script:BRANCH_REGEX) { return $false }
    if ($Branch.StartsWith('-')) { return $false }
    if ($Branch.StartsWith('/') -or $Branch.EndsWith('/')) { return $false }
    if ($Branch -match '(^|/)\.\.(/|$)') { return $false }
    return $true
}

function Test-RepoUrlSafe {
    [CmdletBinding()]
    param([string]$Repo)
    if (-not $Repo) { return $false }
    if ($Repo -notmatch $script:REPO_URL_REGEX) { return $false }
    if ($Repo.StartsWith('-')) { return $false }
    if ($Repo -match "\x00") { return $false }
    return $true
}

function Test-BranchPrefixSafe {
    [CmdletBinding()]
    param([string]$Prefix)
    if (-not $Prefix) { return $false }
    if ($Prefix -notmatch $script:BRANCH_PREFIX_REGEX) { return $false }
    if ($Prefix.StartsWith('-')) { return $false }
    return $true
}
