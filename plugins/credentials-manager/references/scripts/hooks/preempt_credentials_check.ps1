# preempt_credentials_check.ps1
#
# credentials-manager プラグインの PreToolUse フック (PowerShell 7+ 版)。
# 認証情報のやり取りが発生し得るすべてのツール呼び出しを検出し、
# Claude へ「credentials-reader スキルでの照合・自動マッチを最優先で行うこと」を
# additionalContext で通知する。書き込みが必要な場合のみ credentials-manager に
# 引き継ぐ責務分離設計 (参照系: reader / 書き込み系: manager)。

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

$secretPattern = '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
$bearerPattern = '[Bb]earer\s+[A-Za-z0-9._~+/=-]{16,}'

function Test-CredentialFile {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) { return $null }

    $lower = ($Path -replace '\\', '/').ToLowerInvariant()
    $basename = $lower.Split('/')[-1]

    # .env / .env.* の判定 (example/sample/template/dist/test/spec は除外)
    if ($basename -eq '.env') {
        return "環境変数定義ファイル ($basename) を操作"
    }
    if ($basename -like '.env.*') {
        switch -Regex ($basename) {
            '^\.env\.(example|sample|template|dist|test|spec)$' { return $null }
            default { return "環境変数定義ファイル ($basename) を操作" }
        }
    }

    # 完全一致 (ファイル名)
    $exactMatches = @(
        'credentials.json', 'credentials.yml', 'credentials.yaml', 'credential.json',
        'secrets.json', 'secrets.yml', 'secrets.yaml', 'secret.json',
        '.npmrc', '.netrc', '.pgpass', '.git-credentials', '.dockercfg',
        'id_rsa', 'id_dsa', 'id_ecdsa', 'id_ed25519', 'id_xmss',
        'serviceaccountkey.json', 'service-account.json',
        'application_default_credentials.json',
        'gcloud-credentials.json',
        'kubeconfig'
    )
    if ($exactMatches -contains $basename) {
        return "認証情報を含む可能性が高いファイル ($basename) を操作"
    }

    # 拡張子 (秘密鍵 / 証明書)
    $secretExtensions = @('.pem', '.key', '.p12', '.pfx', '.jks', '.keystore', '.crt', '.cer', '.der', '.asc', '.gpg')
    foreach ($ext in $secretExtensions) {
        if ($basename.EndsWith($ext)) {
            return "秘密鍵 / 証明書らしい拡張子のファイル ($basename) を操作"
        }
    }

    # 特殊ディレクトリ配下
    if ($lower -match '(^|/)\.aws/(credentials|config)(\.|$)') {
        return 'AWS 認証情報ファイル (~/.aws/...) を操作'
    }
    if ($lower -match '(^|/)\.docker/config\.json($|\.)') {
        return 'Docker 認証ファイル (~/.docker/config.json) を操作'
    }
    if ($lower -match '(^|/)\.kube/config($|\.)') {
        return 'Kubernetes 認証ファイル (~/.kube/config) を操作'
    }
    if ($lower -match '(^|/)\.ssh/') {
        return 'SSH 鍵格納ディレクトリ (~/.ssh/) のファイルを操作'
    }
    if ($lower -match '(^|/)\.gnupg/') {
        return 'GPG 設定ディレクトリ (~/.gnupg/) のファイルを操作'
    }

    return $null
}

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $payload = $null
    try {
        $payload = $stdin | ConvertFrom-Json -ErrorAction Stop
    } catch {
        exit 0
    }

    if (-not $payload -or -not $payload.PSObject.Properties['tool_name']) { exit 0 }

    $toolName = [string]$payload.tool_name
    if ([string]::IsNullOrEmpty($toolName)) { exit 0 }

    $reason = ''

    function Set-Reason {
        param([string]$NewReason)
        if ([string]::IsNullOrEmpty($script:reason)) {
            $script:reason = $NewReason
        }
    }

    switch -Regex ($toolName) {
        '^(WebFetch|WebSearch)$' {
            Set-Reason "外部 URL アクセスツール ($toolName) の呼び出し"
            break
        }
        '^mcp__' {
            Set-Reason "MCP サーバ呼び出し ($toolName)"
            break
        }
        '^Bash$' {
            $cmd = ''
            if ($payload.PSObject.Properties['tool_input'] -and $payload.tool_input -and $payload.tool_input.PSObject.Properties['command']) {
                $cmd = [string]$payload.tool_input.command
            }
            if (-not [string]::IsNullOrEmpty($cmd)) {
                $extCmdPattern = '(^|[\s;|&(`])(curl|wget|http|httpie|aria2c|scp|sftp|ssh|rsync|gh|az|aws|gcloud|kubectl|doctl|heroku|firebase|vercel|netlify|docker|podman|psql|mysql|mongosh|mongo|redis-cli|terraform|tofu|ansible|ansible-playbook|helm|pulumi|packer|vault|op|bw)(\s|$)'
                if ($cmd -imatch $extCmdPattern) {
                    Set-Reason 'Bash で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行'
                }
                $psCmdPattern = '(Invoke-WebRequest|Invoke-RestMethod|[\s;|&(]iwr\s|[\s;|&(]irm\s)'
                if ($cmd -imatch $psCmdPattern) {
                    Set-Reason 'Bash で PowerShell 系外部通信コマンドを実行'
                }
                $envSetPattern = '(^|[\s;&|(`])(export|set)\s+[A-Za-z_][A-Za-z0-9_]*((TOKEN|KEY|SECRET|PASSWORD|PASSWD|API|AUTH|CREDENTIAL|SESSION|BEARER|PRIVATE)[A-Za-z0-9_]*)?='
                if ($cmd -imatch $envSetPattern) {
                    Set-Reason 'Bash で認証情報らしい環境変数を設定'
                }
                if ($cmd -cmatch $secretPattern) {
                    Set-Reason 'Bash コマンドに認証情報パターンを検出'
                }
                if ($cmd -match $bearerPattern) {
                    Set-Reason 'Bash コマンドに Bearer トークンを検出'
                }
            }
            break
        }
        '^(Read|Write|Edit|MultiEdit|NotebookEdit)$' {
            $filePath = ''
            if ($payload.PSObject.Properties['tool_input'] -and $payload.tool_input -and $payload.tool_input.PSObject.Properties['file_path']) {
                $filePath = [string]$payload.tool_input.file_path
            }
            if (-not [string]::IsNullOrEmpty($filePath)) {
                $fileReason = Test-CredentialFile -Path $filePath
                if ($fileReason) { Set-Reason $fileReason }
            }

            if ($toolName -ne 'Read') {
                if ([string]::IsNullOrEmpty($reason)) {
                    if ($stdin -cmatch $secretPattern) {
                        Set-Reason "$toolName のコンテンツに認証情報パターンを検出"
                    } elseif ($stdin -match $bearerPattern) {
                        Set-Reason "$toolName のコンテンツに Bearer トークンを検出"
                    }
                }
            }
            break
        }
    }

    if ([string]::IsNullOrEmpty($reason)) { exit 0 }

    $message = "[credentials-manager] $reason。credentials-reader を最優先起動して保存済み認証情報を照合してください (1件->自動適用 / 複数件->選択 / 0件->保有有無確認)。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク (先頭4+****+末尾4、8文字以下は全マスク****) で扱ってください。書き込み (保存・編集・削除) は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"

    $output = [ordered]@{
        continue          = $true
        suppressOutput    = $true
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'PreToolUse'
            additionalContext = $message
        }
    }

    $json = $output | ConvertTo-Json -Compress -Depth 10
    [Console]::Out.Write($json)
} catch {
    # 何が起きてもフェイルオープン
}

exit 0
