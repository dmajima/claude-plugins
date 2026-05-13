# detect_credentials_in_prompt.ps1
#
# credentials-manager プラグインの UserPromptSubmit フック (PowerShell 7+ 版)。
# ユーザーが投入したプロンプトに認証情報らしい文字列が含まれている場合、
# credentials-reader スキルでマスキング・既存照合・保存提案を最優先で実施するよう
# Claude へ additionalContext で通知する (保存承諾時のみ credentials-manager に引き継ぎ)。
#
# 検出パターン:
#   - sk-* / ghp_* / gho_* / ghu_* / ghs_* / ghr_*
#   - xoxb-* / xoxp-* / xoxa-* / xoxr-* / xoxs-*
#   - AKIA<16> / AIza<35> / glpat-*
#   - eyJ*.*.* (JWT)
#   - Bearer ... (HTTP Bearer)
#   - Basic <base64> (HTTP Basic)
#   - PEM ヘッダ ("-----BEGIN ... PRIVATE KEY-----")

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) {
        exit 0
    }

    $prompt = $null
    try {
        $payload = $stdin | ConvertFrom-Json -ErrorAction Stop
        if ($payload -and $payload.PSObject.Properties['prompt']) {
            $prompt = [string]$payload.prompt
        }
    } catch {
        # JSON でない / parse 失敗時は何もしない
        exit 0
    }

    if ([string]::IsNullOrEmpty($prompt)) {
        exit 0
    }

    $secretPattern = '(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
    $bearerPattern = '[Bb]earer\s+[A-Za-z0-9._~+/=-]{16,}'
    $basicPattern  = '[Bb]asic\s+[A-Za-z0-9+/=]{16,}'
    $pemPattern    = '-----BEGIN\s+(RSA\s+|DSA\s+|EC\s+|OPENSSH\s+|ENCRYPTED\s+|PGP\s+)?PRIVATE\s+KEY-----'

    $reason = ''
    if ($prompt -cmatch $secretPattern) {
        $reason = 'ユーザープロンプトに認証情報パターンを検出'
    } elseif ($prompt -match $bearerPattern) {
        $reason = 'ユーザープロンプトに Bearer トークンを検出'
    } elseif ($prompt -match $basicPattern) {
        $reason = 'ユーザープロンプトに Basic 認証ヘッダらしい文字列を検出'
    } elseif ($prompt -match $pemPattern) {
        $reason = 'ユーザープロンプトに PEM 形式の秘密鍵を検出'
    }

    if ([string]::IsNullOrEmpty($reason)) {
        exit 0
    }

    $message = "[credentials-manager] $reason。フル値を復唱せずマスク表示 (先頭4+****+末尾4、8文字以下は全マスク****) してください。credentials-reader を最優先起動して既存照合 + 保存提案を行い、ユーザ承諾時のみ credentials-manager に引き継いで保存します。詳細: rules/security/credentials-management.md"

    $output = [ordered]@{
        continue          = $true
        suppressOutput    = $true
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'UserPromptSubmit'
            additionalContext = $message
        }
    }

    $json = $output | ConvertTo-Json -Compress -Depth 10
    [Console]::Out.Write($json)
} catch {
    # 何が起きてもフェイルオープン
}

exit 0
