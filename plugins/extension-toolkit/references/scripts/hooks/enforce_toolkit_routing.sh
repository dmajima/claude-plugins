#!/usr/bin/env bash
# enforce_toolkit_routing.sh - PreToolUse Edit/Write フック
#
# 目的:
#   プラグイン / スキル領域への直接 Edit/Write を検知し、適切な
#   extension-toolkit のスキル（skill-toolkit, command-toolkit,
#   agent-toolkit, hook-toolkit, readme-toolkit, environment-setup-toolkit,
#   marketplace-toolkit, marketplace-publisher, extension-reviewer）を
#   経由するよう強制する。
#
# 入力:
#   stdin: Claude Code から渡される PreToolUse JSON（tool_name, tool_input 含む）
#
# 出力:
#   - 該当外パス: exit 0（通過）
#   - 該当パス + 経由なし: exit 2（ブロック） + stderr に推奨スキル案内
#   - 該当パス + EXTENSION_TOOLKIT_BYPASS=1: exit 0（通過、警告のみ）
#
# bypass:
#   フック自身の修正・extension-toolkit の core 実装変更等、本フックを
#   経由できないシナリオでは環境変数 EXTENSION_TOOLKIT_BYPASS=1 を設定する。

set -euo pipefail

INPUT=$(cat)

# tool_input.file_path を抽出（jq / python 非依存、sed ベース）。
# 想定 JSON: {"tool_name": "Edit|Write|MultiEdit", "tool_input": {"file_path": "...", ...}}
# 最初の "file_path" の値を取得する（Edit/Write/MultiEdit はいずれも file_path がトップに 1 つ）。
# Python の sys.argv 経由ではなく sed を使う理由:
#   pyenv-win 環境では `python -c "..."` の引数渡しで Windows cmd ラッパーが失敗するため。
FILE_PATH=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)

# パス取得失敗 → 通過（フックの誤動作で正常編集を妨げないため）
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# JSON エスケープを最低限元に戻す（\" / \\ / \/）
# シンプルな置換: \\ → \、\" → "、\/ → /
FILE_PATH=$(printf '%s' "$FILE_PATH" | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g' -e 's|\\/|/|g')

# 除外: セッション作業領域・git 内部・テンポラリ
case "$FILE_PATH" in
  *"/.claude/.local/"*|*"/.git/"*|*/tmp/*|/tmp/*)
    exit 0
    ;;
esac

# 検知対象: プラグイン / スキル領域
IS_TARGET=0
case "$FILE_PATH" in
  */plugins/*/.claude-plugin/*|*/plugins/*/skills/*|*/plugins/*/commands/*|*/plugins/*/agents/*|*/plugins/*/hooks/*|*/plugins/*/references/*|*/plugins/*/SKILL.md|*/plugins/*/README.md|*/plugins/*/.claude-plugin/plugin.json)
    IS_TARGET=1
    ;;
  *)
    IS_TARGET=0
    ;;
esac

if [ "$IS_TARGET" -eq 0 ]; then
  exit 0
fi

# bypass フラグ
if [ "${EXTENSION_TOOLKIT_BYPASS:-0}" = "1" ]; then
  printf '[extension-toolkit hook] BYPASS detected — direct edit allowed: %s\n' "$FILE_PATH" >&2
  exit 0
fi

# 推奨スキルの判定（ファイル種別から）
RECOMMENDED=""
case "$FILE_PATH" in
  */SKILL.md)
    RECOMMENDED="skill-toolkit"
    ;;
  */commands/*.md)
    RECOMMENDED="command-toolkit"
    ;;
  */agents/*.md)
    RECOMMENDED="agent-toolkit"
    ;;
  */hooks/hooks.json|*/hooks/*.json|*/hooks/*.sh)
    RECOMMENDED="hook-toolkit"
    ;;
  */README.md)
    RECOMMENDED="readme-toolkit"
    ;;
  */.claude-plugin/plugin.json)
    RECOMMENDED="plugin-toolkit"
    ;;
  */references/scripts/setup/*)
    RECOMMENDED="environment-setup-toolkit"
    ;;
  */references/*|*/evals/*)
    RECOMMENDED="skill-toolkit（または該当する *-toolkit）"
    ;;
  *)
    RECOMMENDED="skill-toolkit / plugin-toolkit のいずれか"
    ;;
esac

cat >&2 <<EOF
[extension-toolkit hook] プラグイン/スキル領域への直接 Edit/Write を検知しました:
  対象ファイル: $FILE_PATH

直接編集する代わりに、以下の extension-toolkit スキルを経由してください:
  推奨: ${RECOMMENDED}

ルーティング指針:
  - SKILL.md          → skill-toolkit
  - commands/*.md     → command-toolkit
  - agents/*.md       → agent-toolkit
  - hooks/*.json/*.sh → hook-toolkit
  - README.md         → readme-toolkit
  - plugin.json       → plugin-toolkit
  - references/scripts/setup/ → environment-setup-toolkit
  - 公開・PR 作成     → marketplace-publisher
  - 多角レビュー      → extension-reviewer

理由:
  extension-toolkit のスキル経由で編集することで、自動レビュー・構造規約遵守・
  バージョン更新・パスポータビリティ検査などの品質ガードが必ず通る運用になります。

bypass:
  フック自身の修正や extension-toolkit core ファイルの修正など、本フック経由が
  不適切な場面では環境変数 EXTENSION_TOOLKIT_BYPASS=1 を設定して再実行してください。
EOF

exit 2
