# install_rule_template.ps1 (PowerShell 版)
#
# credentials-manager プラグインの SessionStart フック。
#
# 「認証情報が必要な処理では credentials-manager を最優先せよ」と定める
# 最重要ルールファイルのテンプレートを、プラグインのインストールスコープに応じた
# ディレクトリにコピーする (既存の場合は何もしない)。
#
# 設計: フェイルオープン (例外時も exit 0、Claude Code を止めない)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

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
    $pluginRootNorm = $pluginRoot.Replace('\', '/')

    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { '' }

    $scope = ''
    $targetDir = ''

    if (-not [string]::IsNullOrEmpty($homeDir)) {
        $homeDirNorm = $homeDir.Replace('\', '/')
        $homePrefix = "${homeDirNorm}/.claude/"
        # case-insensitive prefix 比較 (OrdinalIgnoreCase)
        if ($pluginRootNorm.StartsWith($homePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $scope = 'user'
            $targetDir = Join-Path $homeDir '.claude/rules/security'
        }
    }

    if ([string]::IsNullOrEmpty($scope)) {
        if ([string]::IsNullOrEmpty($projectDir)) {
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
    }
    catch {
        exit 0
    }

    try {
        Copy-Item -LiteralPath $template -Destination $target -ErrorAction Stop
    }
    catch {
        exit 0
    }

    $message = "[credentials-manager] ${scope} 向けにルール 'credentials-management.md' を ${target} に配置しました。本ルールは認証情報・URL アクセス・外部通信を伴うすべての処理で参照系を credentials-reader、書き込み系を credentials-manager に分離して最優先起動するよう定めています。CLAUDE.md からの参照追加が未済みの場合、ユーザーに案内してください。"

    $output = @{
        continue = $true
        suppressOutput = $false
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
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
