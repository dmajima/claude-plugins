#!/usr/bin/env bash
# detect_credentials_in_prompt.sh
#
# credentials-manager プラグインの UserPromptSubmit フック。
# ユーザーが投入したプロンプトに認証情報らしい文字列が含まれている場合、
# credentials-reader スキルでマスキング・既存照合・保存提案を最優先で実施するよう
# Claude へ additionalContext で通知する（保存承諾時のみ credentials-manager に引き継ぎ）。
#
# 検出パターン:
#   - sk-* / ghp_* / gho_* / ghu_* / ghs_* / ghr_*
#   - xoxb-* / xoxp-* / xoxa-* / xoxr-* / xoxs-*
#   - AKIA<16> / AIza<35> / glpat-*
#   - eyJ*.*.* (JWT)
#   - Bearer ... (HTTP Bearer)
#   - Basic <base64> (HTTP Basic)
#   - PEM ヘッダ ("-----BEGIN ... PRIVATE KEY-----")

set -uo pipefail

INPUT="$(cat)"
INPUT_FLAT="$(printf '%s' "$INPUT" | tr '\n\t' '  ')"

PROMPT="$(printf '%s' "$INPUT_FLAT" \
  | grep -oE '"prompt"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' \
  | head -1 \
  | sed -E 's/^"prompt"[[:space:]]*:[[:space:]]*"//; s/"$//')"

if [[ -z "$PROMPT" ]]; then
  exit 0
fi

SECRET_PATTERN='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
BEARER_PATTERN='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'
BASIC_PATTERN='[Bb]asic[[:space:]]+[A-Za-z0-9+/=]{16,}'
PEM_PATTERN='-----BEGIN[[:space:]]+(RSA[[:space:]]+|DSA[[:space:]]+|EC[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+|PGP[[:space:]]+)?PRIVATE[[:space:]]+KEY-----'

REASON=""

if printf '%s' "$PROMPT" | grep -qE -e "$SECRET_PATTERN"; then
  REASON="ユーザープロンプトに認証情報パターンを検出"
fi
if [[ -z "$REASON" ]] && printf '%s' "$PROMPT" | grep -qE -e "$BEARER_PATTERN"; then
  REASON="ユーザープロンプトに Bearer トークンを検出"
fi
if [[ -z "$REASON" ]] && printf '%s' "$PROMPT" | grep -qE -e "$BASIC_PATTERN"; then
  REASON="ユーザープロンプトに Basic 認証ヘッダらしい文字列を検出"
fi
if [[ -z "$REASON" ]] && printf '%s' "$PROMPT" | grep -qE -e "$PEM_PATTERN"; then
  REASON="ユーザープロンプトに PEM 形式の秘密鍵を検出"
fi

if [[ -z "$REASON" ]]; then
  exit 0
fi

# JSON 用エスケープ
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

ESCAPED_REASON="$(escape_json "$REASON")"

cat <<EOF
{
  "continue": true,
  "suppressOutput": true,
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[credentials-manager] ${ESCAPED_REASON}。フル値を復唱せずマスク表示（先頭4+****+末尾4、8文字以下は全マスク****）してください。credentials-reader を最優先起動して既存照合 + 保存提案を行い、ユーザ承諾時のみ credentials-manager に引き継いで保存します。詳細: rules/security/credentials-management.md"
  }
}
EOF

exit 0
