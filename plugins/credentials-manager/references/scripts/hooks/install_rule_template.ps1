# install_rule_template.ps1
#
# credentials-manager プラグインの SessionStart フック (PowerShell 7+ 版)。
# 「認証情報が必要な処理では credentials-manager を最優先せよ」と定める
# 最重要ルールファイルのテンプレートを、プラグインのインストールスコープに応じた
# ディレクトリにコピーする (既存の場合は何もしない)。
#
# スコープ判定:
#   - CLAUDE_PLUGIN_ROOT が ${HOME}/.claude/ 配下           -> user スコープ
#       配置先: ${HOME}/.claude/rules/security/credentials-management.md
#   - それ以外 (プロジェクト内 .claude/plugins/cache/...)  -> project / local スコープ
#       配置先: ${CLAUDE_PROJECT_DIR}/.claude/rules/security/credentials-management.md
#
# 出力: SessionStart の hookSpecificOutput.additionalContext で Claude へ通知。
# 設計: フェイルオープン (例外時も exit 0、Claude Code を止めない)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
    $projectDir = $env:CLAUDE_PROJECT_DIR

    if ([string]::IsNullOrEmpty($pluginRoot)) {
        exit 0
    }

    $template = Join-Path $pluginRoot 'references/templates/rules/security/credentials-management.md'
    if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
        exit 0
    }

    # パス正規化 (バックスラッシュ -> スラッシュ)
    $pluginRootNorm = $pluginRoot -replace '\\', '/'

    $homeDir = $env:USERPROFILE
    if ([string]::IsNullOrEmpty($homeDir)) { $homeDir = $env:HOME }

    $scope = $null
    $targetDir = $null

    if (-not [string]::IsNullOrEmpty($homeDir)) {
        $homeDirNorm = $homeDir -replace '\\', '/'
        $homePrefix = "$homeDirNorm/.claude/"
        if ($pluginRootNorm.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $scope = 'user'
            $targetDir = Join-Path $homeDir '.claude/rules/security'
        }
    }

    if (-not $scope) {
        if ([string]::IsNullOrEmpty($projectDir)) {
            # 判定不能 (リモート環境などプロジェクトディレクトリも HOME も特定不可)
            exit 0
        }
        $scope = 'project'
        $targetDir = Join-Path $projectDir '.claude/rules/security'
    }

    $target = Join-Path $targetDir 'credentials-management.md'

    # 既配置時は何もしない (ユーザー編集を尊重)
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        exit 0
    }

    try {
        New-Item -ItemType Directory -Force -Path $targetDir -ErrorAction Stop | Out-Null
        Copy-Item -LiteralPath $template -Destination $target -ErrorAction Stop
    } catch {
        exit 0
    }

    # Claude へ通知 (hookSpecificOutput.additionalContext)
    $message = "[credentials-manager] $scope 向けにルール 'credentials-management.md' を $target に配置しました。本ルールは認証情報・URL アクセス・外部通信を伴うすべての処理で参照系を credentials-reader、書き込み系を credentials-manager に分離して最優先起動するよう定めています。CLAUDE.md からの参照追加が未済みの場合、ユーザーに案内してください。"

    $output = [ordered]@{
        continue          = $true
        suppressOutput    = $false
        hookSpecificOutput = [ordered]@{
            hookEventName     = 'SessionStart'
            additionalContext = $message
        }
    }

    $json = $output | ConvertTo-Json -Compress -Depth 10
    [Console]::Out.Write($json)
} catch {
    # 何が起きてもフェイルオープン
}

exit 0
