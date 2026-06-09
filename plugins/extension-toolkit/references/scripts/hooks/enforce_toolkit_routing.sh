#!/usr/bin/env bash
# enforce_toolkit_routing.sh - PreToolUse Edit/Write フック (Bash 版、警告型)
#
#
# 目的:
#   プラグイン / スキル領域への直接 Edit/Write を検知し、適切な
#   extension-toolkit のスキル利用を *推奨* する (ブロックはしない)。

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stdin="$(cat)"
[[ -z "${stdin//[[:space:]]/}" ]] && exit 0

file_path="$(printf '%s' "$stdin" | jq -er '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$file_path" ]] && exit 0

# パス正規化
normalized_path="${file_path//\\/\/}"

# 除外: セッション作業領域・git 内部・テンポラリ
if [[ "$normalized_path" =~ /\.claude/\.local/ \
   || "$normalized_path" =~ /\.git/ \
   || "$normalized_path" =~ /tmp/ \
   || "$normalized_path" =~ ^/tmp/ ]]; then
  exit 0
fi

# 検知対象判定
target_patterns=(
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
is_target=0
for pattern in "${target_patterns[@]}"; do
  if [[ "$normalized_path" =~ $pattern ]]; then
    is_target=1
    break
  fi
done
[[ "$is_target" -eq 0 ]] && exit 0

# 推奨スキル判定
if [[ "$normalized_path" =~ /SKILL\.md$ ]]; then
  recommended="skill-toolkit"
elif [[ "$normalized_path" =~ /commands/[^/]+\.md$ ]]; then
  recommended="command-toolkit"
elif [[ "$normalized_path" =~ /agents/[^/]+\.md$ ]]; then
  recommended="agent-toolkit"
elif [[ "$normalized_path" =~ /hooks/(hooks\.json|[^/]+\.json|[^/]+\.sh)$ ]]; then
  recommended="hook-toolkit"
elif [[ "$normalized_path" =~ /README\.md$ ]]; then
  recommended="readme-toolkit"
elif [[ "$normalized_path" =~ /\.claude-plugin/plugin\.json$ ]]; then
  recommended="plugin-toolkit"
elif [[ "$normalized_path" =~ /references/scripts/setup/ ]]; then
  recommended="environment-setup-toolkit"
elif [[ "$normalized_path" =~ /references/ || "$normalized_path" =~ /evals/ ]]; then
  recommended="skill-toolkit (または該当する *-toolkit)"
else
  recommended="skill-toolkit / plugin-toolkit のいずれか"
fi

cat >&2 <<EOF
[extension-toolkit hook] プラグイン/スキル領域への直接 Edit/Write を検知 (情報提示のみ・編集は許可):
  対象ファイル: $file_path
  推奨スキル: $recommended

新規作成・大規模改修・構造変更を伴う場合は、上記 toolkit を経由することで
構造規約遵守・パスポータビリティ検査・evals 整合などの品質ガードが通ります。
軽微な編集 (typo / コメント / 1~数行修正) は直接編集で問題ありません。

参考ルーティング:
  SKILL.md -> skill-toolkit / commands/*.md -> command-toolkit /
  agents/*.md -> agent-toolkit / hooks/* -> hook-toolkit /
  README.md -> readme-toolkit / plugin.json -> plugin-toolkit /
  references/scripts/setup/ -> environment-setup-toolkit /
  公開 -> marketplace-publish / レビュー -> extension-review

なお、バージョン更新漏れは Stop フック (check_version_bump.sh) で
セッション終了時に検出されます。
EOF

exit 0
