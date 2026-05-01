#!/usr/bin/env bash
# enforce_toolkit_routing.sh - PreToolUse Edit/Write フック（警告型、ADR-026 v2）
#
# 目的:
#   プラグイン / スキル領域への直接 Edit/Write を検知し、適切な
#   extension-toolkit のスキル（skill-toolkit, command-toolkit,
#   agent-toolkit, hook-toolkit, readme-toolkit, environment-setup-toolkit,
#   marketplace-toolkit, marketplace-publisher, extension-reviewer）の
#   利用を **推奨** する（ブロックはしない）。
#
#   ハードブロック型（旧設計）は (1) セルフレビューの反復を阻害、
#   (2) 軽微な編集にも重い toolkit 起動を強制、(3) bypass 運用が常態化、
#   といった過剰制約となるため警告型に変更（ADR-026 v2）。
#
#   バージョン更新漏れの防止は本フックではなく Stop フック
#   `check_version_bump.sh` で別途担当する。
#
# 入力:
#   stdin: Claude Code から渡される PreToolUse JSON（tool_name, tool_input 含む）
#
# 出力:
#   - 該当外パス: exit 0（通過、無音）
#   - 該当パス: exit 0（通過） + stderr に推奨スキル名を提示
#
# 設計上の決定:
#   - 常に exit 0（編集をブロックしない）
#   - Claude は stderr メッセージを見て、編集規模に応じて
#     toolkit 起動の要否を自律判断する
#   - bypass フラグは不要（廃止）

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
[extension-toolkit hook] プラグイン/スキル領域への直接 Edit/Write を検知（情報提示のみ・編集は許可）:
  対象ファイル: $FILE_PATH
  推奨スキル: ${RECOMMENDED}

新規作成・大規模改修・構造変更を伴う場合は、上記 toolkit を経由することで
構造規約遵守・パスポータビリティ検査・evals 整合などの品質ガードが通ります。
軽微な編集（typo / コメント / 1〜数行修正）は直接編集で問題ありません。

参考ルーティング:
  SKILL.md → skill-toolkit / commands/*.md → command-toolkit /
  agents/*.md → agent-toolkit / hooks/* → hook-toolkit /
  README.md → readme-toolkit / plugin.json → plugin-toolkit /
  references/scripts/setup/ → environment-setup-toolkit /
  公開 → marketplace-publisher / レビュー → extension-reviewer

なお、バージョン更新漏れは Stop フック (check_version_bump.sh) で
セッション終了時に検出されます。
EOF

# 警告のみ。編集はブロックしない（ADR-026 v2、案 A 採用）
exit 0
