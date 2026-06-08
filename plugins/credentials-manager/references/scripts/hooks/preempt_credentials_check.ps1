# preempt_credentials_check.ps1 (PowerShell 版)
#
# credentials-manager プラグインの PreToolUse フック。
#
# 認証情報のやり取りが発生し得るすべてのツール呼び出しを検出し、
# Claude へ「credentials-reader スキルでの照合・自動マッチを最優先で行うこと」を
# additionalContext で通知する。
#
# 設計: フェイルオープン (例外時も exit 0)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# 検出パターン
$SECRET_PATTERN = '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
$BEARER_PATTERN = '[Bb]earer\s+[A-Za-z0-9._~+/=-]{16,}'

function Test-CredentialFile {
    param([string]$Path)

    if ([string]::IsNullOrEmpty($Path)) {
        return ''
    }

    $lower = $Path.Replace('\', '/').ToLowerInvariant()
    $basename = $lower.Split('/')[-1]

    # .env / .env.* の判定 (example/sample/template/dist/test/spec は除外)
    if ($basename -eq '.env') {
        return "環境変数定義ファイル ($basename) を操作"
    }
    if ($basename -like '.env.*') {
        $excludes = @('.env.example', '.env.sample', '.env.template', '.env.dist', '.env.test', '.env.spec')
        if ($basename -notin $excludes) {
            return "環境変数定義ファイル ($basename) を操作"
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
    if ($basename -in $exactMatches) {
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

    return ''
}

try {
    $stdinData = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdinData)) {
        exit 0
    }

    # JSON 解析
    try {
        $json = $stdinData | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        exit 0
    }

    $toolName = $json.tool_name
    if ([string]::IsNullOrEmpty($toolName)) {
        exit 0
    }

    $reason = ''

    switch -Regex ($toolName) {
        '^(WebFetch|WebSearch)$' {
            if ([string]::IsNullOrEmpty($reason)) {
                $reason = "外部 URL アクセスツール ($toolName) の呼び出し"
            }
        }
        '^mcp__' {
            if ([string]::IsNullOrEmpty($reason)) {
                $reason = "MCP サーバ呼び出し ($toolName)"
            }
        }
        '^Bash$' {
            $cmd = $json.tool_input.command
            if (-not [string]::IsNullOrEmpty($cmd)) {
                # 外部通信 / IaC / シークレット管理 CLI
                $extCmdPattern = '(^|[\s;|&(`])(curl|wget|http|httpie|aria2c|scp|sftp|ssh|rsync|gh|az|aws|gcloud|kubectl|doctl|heroku|firebase|vercel|netlify|docker|podman|psql|mysql|mongosh|mongo|redis-cli|terraform|tofu|ansible|ansible-playbook|helm|pulumi|packer|vault|op|bw)([\s]|$)'
                if ([string]::IsNullOrEmpty($reason) -and ($cmd -match $extCmdPattern)) {
                    $reason = 'Bash で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行'
                }
                $psCmdPattern = '(Invoke-WebRequest|Invoke-RestMethod|[\s;|&(]iwr[\s]|[\s;|&(]irm[\s])'
                if ([string]::IsNullOrEmpty($reason) -and ($cmd -match $psCmdPattern)) {
                    $reason = 'Bash で PowerShell 系外部通信コマンドを実行'
                }
                $envSetPattern = '(^|[\s;&|(`])(export|set)\s+[A-Za-z_][A-Za-z0-9_]*((TOKEN|KEY|SECRET|PASSWORD|PASSWD|API|AUTH|CREDENTIAL|SESSION|BEARER|PRIVATE)[A-Za-z0-9_]*)?='
                if ([string]::IsNullOrEmpty($reason) -and ($cmd -match $envSetPattern)) {
                    $reason = 'Bash で認証情報らしい環境変数を設定'
                }
                if ([string]::IsNullOrEmpty($reason) -and ($cmd -cmatch $SECRET_PATTERN)) {
                    $reason = 'Bash コマンドに認証情報パターンを検出'
                }
                if ([string]::IsNullOrEmpty($reason) -and ($cmd -match $BEARER_PATTERN)) {
                    $reason = 'Bash コマンドに Bearer トークンを検出'
                }
            }
        }
        '^(Read|Write|Edit|MultiEdit|NotebookEdit)$' {
            $filePath = $json.tool_input.file_path
            if (-not [string]::IsNullOrEmpty($filePath)) {
                $fileReason = Test-CredentialFile -Path $filePath
                if (-not [string]::IsNullOrEmpty($fileReason) -and [string]::IsNullOrEmpty($reason)) {
                    $reason = $fileReason
                }
            }
            if ($toolName -ne 'Read' -and [string]::IsNullOrEmpty($reason)) {
                if ($stdinData -cmatch $SECRET_PATTERN) {
                    $reason = "$toolName のコンテンツに認証情報パターンを検出"
                }
                elseif ($stdinData -match $BEARER_PATTERN) {
                    $reason = "$toolName のコンテンツに Bearer トークンを検出"
                }
            }
        }
    }

    if ([string]::IsNullOrEmpty($reason)) {
        exit 0
    }

    $message = "[credentials-manager] ${reason}。credentials-reader を最優先起動して保存済み認証情報を照合してください (1件->自動適用 / 複数件->選択 / 0件->保有有無確認)。コマンド・コンテンツに認証情報パターンが含まれる場合はフル値を復唱せずマスク (先頭4+****+末尾4、8文字以下は全マスク****) で扱ってください。書き込み (保存・編集・削除) は credentials-manager に引き継ぎます。詳細: rules/security/credentials-management.md"

    $output = @{
        continue = $true
        suppressOutput = $true
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            additionalContext = $message
        }
    } | ConvertTo-Json -Depth 3 -Compress

    Write-Output $output

    exit 0
}
catch {
    # フェイルオープン: 例外時も exit 0
    exit 0
}
