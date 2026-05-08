#!/usr/bin/env bash
# install_rule_template.sh
#
# credentials-manager プラグインの SessionStart フック。
# 「認証情報が必要な処理では credentials-manager を最優先せよ」と定める
# 最重要ルールファイルのテンプレートを、プラグインのインストールスコープに応じた
# ディレクトリにコピーする（既存の場合は何もしない）。
#
# スコープ判定:
#   - CLAUDE_PLUGIN_ROOT が ${HOME}/.claude/ 配下           → user スコープ
#       配置先: ${HOME}/.claude/rules/security/credentials-management.md
#   - それ以外（プロジェクト内 .claude/plugins/cache/...）  → project / local スコープ
#       配置先: ${CLAUDE_PROJECT_DIR}/.claude/rules/security/credentials-management.md
#
# 出力: SessionStart の hookSpecificOutput.additionalContext で Claude へ通知。

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"

# テンプレート不在 / 環境変数欠如時は何もせず終了
if [[ -z "$PLUGIN_ROOT" ]]; then
  exit 0
fi

TEMPLATE="$PLUGIN_ROOT/references/templates/rules/security/credentials-management.md"
if [[ ! -f "$TEMPLATE" ]]; then
  exit 0
fi

# Windows のパス区切りを正規化（Git Bash 対応）
normalize_path() {
  local p="$1"
  p="${p//\\//}"
  printf '%s' "$p"
}

PLUGIN_ROOT_NORM="$(normalize_path "$PLUGIN_ROOT")"
HOME_DIR="${HOME:-${USERPROFILE:-}}"
HOME_DIR_NORM="$(normalize_path "$HOME_DIR")"

# スコープ判定
SCOPE=""
TARGET_DIR=""

if [[ -n "$HOME_DIR_NORM" && "$PLUGIN_ROOT_NORM" == "$HOME_DIR_NORM/.claude/"* ]]; then
  SCOPE="user"
  TARGET_DIR="$HOME_DIR_NORM/.claude/rules/security"
elif [[ -n "$PROJECT_DIR" ]]; then
  PROJECT_DIR_NORM="$(normalize_path "$PROJECT_DIR")"
  SCOPE="project"
  TARGET_DIR="$PROJECT_DIR_NORM/.claude/rules/security"
else
  # 判定不能（リモート環境などプロジェクトディレクトリも HOME も特定不可）
  exit 0
fi

TARGET="$TARGET_DIR/credentials-management.md"

# 既配置時は何もしない（ユーザー編集を尊重）
if [[ -f "$TARGET" ]]; then
  exit 0
fi

# 配置
if ! mkdir -p "$TARGET_DIR" 2>/dev/null; then
  exit 0
fi
if ! cp "$TEMPLATE" "$TARGET" 2>/dev/null; then
  exit 0
fi

# Claude へ通知（hookSpecificOutput.additionalContext）
# 既存の他フック実装と同様、JSON は heredoc で組み立てる
read -r -d '' MESSAGE <<EOF || true
[credentials-manager] ${SCOPE} 向けにルール 'credentials-management.md' を ${TARGET} に配置しました。本ルールは認証情報・URL アクセス・外部通信を伴うすべての処理で参照系を credentials-reader、書き込み系を credentials-manager に分離して最優先起動するよう定めています。CLAUDE.md からの参照追加が未済みの場合、ユーザーに案内してください。
EOF

# JSON 文字列としてエスケープ（"・\・改行）
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

ESCAPED="$(escape_json "$MESSAGE")"

cat <<EOF
{
  "continue": true,
  "suppressOutput": false,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${ESCAPED}"
  }
}
EOF

exit 0
