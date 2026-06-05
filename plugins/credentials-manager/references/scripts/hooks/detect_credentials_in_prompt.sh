#!/usr/bin/env bash
# detect_credentials_in_prompt.sh (Bash 版)
#
# credentials-manager プラグインの UserPromptSubmit フック。
#
# ユーザーが投入したプロンプトに認証情報らしい文字列が含まれている場合、
# credentials-reader スキルでマスキング・既存照合・保存提案を最優先で実施するよう
# Claude へ additionalContext で通知する。
#
# 設計: フェイルオープン (例外時も exit 0)

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stdin="$(cat)"
if [[ -z "${stdin//[[:space:]]/}" ]]; then
  exit 0
fi

# JSON 解析（無効なら exit 0）
prompt="$(printf '%s' "$stdin" | jq -er '.prompt // empty' 2>/dev/null)"
if [[ -z "$prompt" ]]; then
  exit 0
fi

# 検出パターン
secret_pattern='(sk-[A-Za-z0-9_-]{16,}|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghu_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|ghr_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|glpat-[A-Za-z0-9_-]{20,}|eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)'
bearer_pattern='[Bb]earer[[:space:]]+[A-Za-z0-9._~+/=-]{16,}'
basic_pattern='[Bb]asic[[:space:]]+[A-Za-z0-9+/=]{16,}'
pem_pattern='-----BEGIN[[:space:]]+(RSA[[:space:]]+|DSA[[:space:]]+|EC[[:space:]]+|OPENSSH[[:space:]]+|ENCRYPTED[[:space:]]+|PGP[[:space:]]+)?PRIVATE[[:space:]]+KEY-----'

reason=""
# secret_pattern は case-sensitive (PowerShell の -cmatch 相当)
if [[ "$prompt" =~ $secret_pattern ]]; then
  reason="ユーザープロンプトに認証情報パターンを検出"
# 以降は case-insensitive (PowerShell の -match 相当)
elif printf '%s' "$prompt" | grep -qE "$bearer_pattern" 2>/dev/null; then
  reason="ユーザープロンプトに Bearer トークンを検出"
elif printf '%s' "$prompt" | grep -qE "$basic_pattern" 2>/dev/null; then
  reason="ユーザープロンプトに Basic 認証ヘッダらしい文字列を検出"
elif printf '%s' "$prompt" | grep -qE "$pem_pattern" 2>/dev/null; then
  reason="ユーザープロンプトに PEM 形式の秘密鍵を検出"
fi

if [[ -z "$reason" ]]; then
  exit 0
fi

message="[credentials-manager] ${reason}。フル値を復唱せずマスク表示 (先頭4+****+末尾4、8文字以下は全マスク****) してください。credentials-reader を最優先起動して既存照合 + 保存提案を行い、ユーザ承諾時のみ credentials-manager に引き継いで保存します。詳細: rules/security/credentials-management.md"

jq -nc --arg msg "$message" '{
  continue: true,
  suppressOutput: true,
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: $msg
  }
}'

exit 0
