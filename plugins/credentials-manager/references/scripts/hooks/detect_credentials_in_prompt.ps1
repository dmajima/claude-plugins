# detect_credentials_in_prompt.ps1 (PowerShell 版)
#
# credentials-manager プラグインの UserPromptSubmit フック。
#
# ユーザーが投入したプロンプトに認証情報らしい文字列が含まれている場合、
# credentials-reader スキルでマスキング・既存照合・保存提案を最優先で実施するよう
# Claude へ additionalContext で通知する。
#
# 設計: フェイルオープン (例外時も exit 0)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

try {
    $stdinData = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdinData)) {
        exit 0
    }

    # JSON 解析（無効なら exit 0）
    try {
        $json = $stdinData | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        exit 0
    }

    $prompt = $json.prompt
    if ([string]::IsNullOrEmpty($prompt)) {
        exit 0
    }

    # 検出パターン
    $secretPattern = '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
    $bearerPattern = '[Bb]earer\s+[A-Za-z0-9._~+/=-]{16,}'
    $basicPattern = '[Bb]asic\s+[A-Za-z0-9+/=]{16,}'
    $pemPattern = '-----BEGIN\s+(RSA\s+|DSA\s+|EC\s+|OPENSSH\s+|ENCRYPTED\s+|PGP\s+)?PRIVATE\s+KEY-----'

    $reason = ''
    # secret_pattern は case-sensitive (-cmatch)
    if ($prompt -cmatch $secretPattern) {
        $reason = 'ユーザープロンプトに認証情報パターンを検出'
    }
    # 以降は case-insensitive (-match)
    elseif ($prompt -match $bearerPattern) {
        $reason = 'ユーザープロンプトに Bearer トークンを検出'
    }
    elseif ($prompt -match $basicPattern) {
        $reason = 'ユーザープロンプトに Basic 認証ヘッダらしい文字列を検出'
    }
    elseif ($prompt -match $pemPattern) {
        $reason = 'ユーザープロンプトに PEM 形式の秘密鍵を検出'
    }

    if ([string]::IsNullOrEmpty($reason)) {
        exit 0
    }

    $message = "[credentials-manager] ${reason}。フル値を復唱せずマスク表示 (先頭4+****+末尾4、8文字以下は全マスク****) してください。credentials-reader を最優先起動して既存照合 + 保存提案を行い、ユーザ承諾時のみ credentials-manager に引き継いで保存します。詳細: rules/security/credentials-management.md"

    $output = @{
        continue = $true
        suppressOutput = $true
        hookSpecificOutput = @{
            hookEventName = 'UserPromptSubmit'
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
