# enforce_toolkit_routing.ps1 - PreToolUse Edit/Write hook (PowerShell version, warning only)
#
#
# 目的:
#   プラグイン / スキル領域への直接 Edit/Write を検知し、適切な
#   extension-toolkit のスキル利用を *推奨* する (ブロックはしない)。

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# stdin を読み取り
$stdinData = ''
try { $stdinData = [Console]::In.ReadToEnd() } catch {}
if ([string]::IsNullOrWhiteSpace($stdinData)) { exit 0 }

try {
    $input_obj = $stdinData | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

$filePath = $input_obj.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($filePath)) { exit 0 }

# パス正規化
$normalizedPath = $filePath -replace '\\', '/'

# 除外: セッション作業領域・git 内部・テンポラリ
if ($normalizedPath -match '/\.claude/\.local/' -or
    $normalizedPath -match '/\.git/' -or
    $normalizedPath -match '/tmp/' -or
    $normalizedPath -match '^/tmp/') {
    exit 0
}

# 検知対象判定
$targetPatterns = @(
    '/plugins/[^/]+/\.claude-plugin/'
    '/plugins/[^/]+/skills/'
    '/plugins/[^/]+/commands/'
    '/plugins/[^/]+/agents/'
    '/plugins/[^/]+/hooks/'
    '/plugins/[^/]+/references/'
    '/plugins/[^/]+/SKILL\.md$'
    '/plugins/[^/]+/README\.md$'
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
$recommended = ''
if ($normalizedPath -match '/SKILL\.md$') {
    $recommended = 'skill-toolkit'
} elseif ($normalizedPath -match '/commands/[^/]+\.md$') {
    $recommended = 'command-toolkit'
} elseif ($normalizedPath -match '/agents/[^/]+\.md$') {
    $recommended = 'agent-toolkit'
} elseif ($normalizedPath -match '/hooks/(hooks\.json|[^/]+\.json|[^/]+\.ps1)$') {
    $recommended = 'hook-toolkit'
} elseif ($normalizedPath -match '/README\.md$') {
    $recommended = 'readme-toolkit'
} elseif ($normalizedPath -match '/\.claude-plugin/plugin\.json$') {
    $recommended = 'plugin-toolkit'
} elseif ($normalizedPath -match '/references/scripts/setup/') {
    $recommended = 'environment-setup-toolkit'
} elseif ($normalizedPath -match '/references/' -or $normalizedPath -match '/evals/') {
    $recommended = 'skill-toolkit (または該当する *-toolkit)'
} else {
    $recommended = 'skill-toolkit / plugin-toolkit のいずれか'
}

[Console]::Error.WriteLine(@"
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

なお、バージョン更新漏れは Stop hook (check_version_bump.ps1) で
セッション終了時に検出されます。
"@)

exit 0
