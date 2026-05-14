# enforce_toolkit_routing.ps1 - PreToolUse Edit/Write フック (PowerShell 7+ 版、警告型、ADR-026 v2)
#
# 目的:
#   プラグイン / スキル領域への直接 Edit/Write を検知し、適切な
#   extension-toolkit のスキル (skill-toolkit, command-toolkit,
#   agent-toolkit, hook-toolkit, readme-toolkit, environment-setup-toolkit,
#   marketplace-toolkit, marketplace-publisher, extension-reviewer) の
#   利用を *推奨* する (ブロックはしない)。
#
# 入力:
#   stdin: Claude Code から渡される PreToolUse JSON (tool_name, tool_input 含む)
#
# 出力:
#   - 該当外パス: exit 0 (通過、無音)
#   - 該当パス: exit 0 (通過) + stderr に推奨スキル名を提示

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Continue'

try {
    $stdin = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($stdin)) { exit 0 }

    $payload = $null
    try {
        $payload = $stdin | ConvertFrom-Json -ErrorAction Stop
    } catch { exit 0 }

    if (-not $payload -or -not $payload.tool_input) { exit 0 }
    $filePath = ''
    if ($payload.tool_input.PSObject.Properties['file_path']) {
        $filePath = [string]$payload.tool_input.file_path
    }
    if ([string]::IsNullOrEmpty($filePath)) { exit 0 }

    # パス正規化 (バックスラッシュ -> スラッシュ)
    $normalizedPath = $filePath -replace '\\', '/'

    # 除外: セッション作業領域・git 内部・テンポラリ
    if ($normalizedPath -match '/\.claude/\.local/' -or
        $normalizedPath -match '/\.git/' -or
        $normalizedPath -match '/tmp/' -or
        $normalizedPath.StartsWith('/tmp/')) {
        exit 0
    }

    # 検知対象判定
    $targetPatterns = @(
        '/plugins/[^/]+/\.claude-plugin/',
        '/plugins/[^/]+/skills/',
        '/plugins/[^/]+/commands/',
        '/plugins/[^/]+/agents/',
        '/plugins/[^/]+/hooks/',
        '/plugins/[^/]+/references/',
        '/plugins/[^/]+/SKILL\.md$',
        '/plugins/[^/]+/README\.md$',
        '/plugins/[^/]+/\.claude-plugin/plugin\.json$'
    )

    $isTarget = $false
    foreach ($pattern in $targetPatterns) {
        if ($normalizedPath -match $pattern) {
            $isTarget = $true
            break
        }
    }

    if (-not $isTarget) { exit 0 }

    # 推奨スキル判定
    $recommended = if ($normalizedPath -match '/SKILL\.md$') {
        'skill-toolkit'
    } elseif ($normalizedPath -match '/commands/[^/]+\.md$') {
        'command-toolkit'
    } elseif ($normalizedPath -match '/agents/[^/]+\.md$') {
        'agent-toolkit'
    } elseif ($normalizedPath -match '/hooks/(hooks\.json|[^/]+\.json|[^/]+\.sh|[^/]+\.ps1)$') {
        'hook-toolkit'
    } elseif ($normalizedPath -match '/README\.md$') {
        'readme-toolkit'
    } elseif ($normalizedPath -match '/\.claude-plugin/plugin\.json$') {
        'plugin-toolkit'
    } elseif ($normalizedPath -match '/references/scripts/setup/') {
        'environment-setup-toolkit'
    } elseif ($normalizedPath -match '/references/' -or $normalizedPath -match '/evals/') {
        'skill-toolkit (または該当する *-toolkit)'
    } else {
        'skill-toolkit / plugin-toolkit のいずれか'
    }

    $msg = @"
[extension-toolkit hook] プラグイン/スキル領域への直接 Edit/Write を検知 (情報提示のみ・編集は許可):
  対象ファイル: $filePath
  推奨スキル: $recommended

新規作成・大規模改修・構造変更を伴う場合は、上記 toolkit を経由することで
構造規約遵守・パスポータビリティ検査・evals 整合などの品質ガードが通ります。
軽微な編集 (typo / コメント / 1~数行修正) は直接編集で問題ありません。

参考ルーティング:
  SKILL.md -> skill-toolkit / commands/*.md -> command-toolkit /
  agents/*.md -> agent-toolkit / hooks/* -> hook-toolkit /
  README.md -> readme-toolkit / plugin.json -> plugin-toolkit /
  references/scripts/setup/ -> environment-setup-toolkit /
  公開 -> marketplace-publisher / レビュー -> extension-reviewer

なお、バージョン更新漏れは Stop フック (check_version_bump.ps1) で
セッション終了時に検出されます。
"@

    [Console]::Error.WriteLine($msg)
} catch {
    # フェイルオープン
}

exit 0
