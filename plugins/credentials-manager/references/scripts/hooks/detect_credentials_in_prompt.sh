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

# 秘密情報のパターン（PreToolUse のフックと共有する）
hooks_dir="${BASH_SOURCE[0]%/*}"
[[ $hooks_dir == "${BASH_SOURCE[0]}" ]] && hooks_dir=.
# shellcheck source=lib/credential_patterns.sh
if ! source "$hooks_dir/lib/credential_patterns.sh" 2>/dev/null; then
  echo "[credentials-manager] lib/credential_patterns.sh を読み込めないため、検査を省略します" >&2
  exit 0
fi

stdin="$(cat)"
# 空白以外の文字が無ければ終了する。"${stdin//[[:space:]]/}" で空白を除去する判定は、空白の多い大きな入力
# （貼り付けたログ等）で入力長の二乗の時間がかかり、hooks.json の timeout を超えて検査が無言で欠落するため使わない
if [[ ! $stdin =~ [^[:space:]] ]]; then
  exit 0
fi

# JSON 解析（無効なら exit 0）
prompt="$(printf '%s' "$stdin" | jq -er '.prompt // empty' 2>/dev/null)"
if [[ -z "$prompt" ]]; then
  exit 0
fi

# 照合は bash 組み込みの正規表現で行う（grep に渡すと、- で始まる PEM のパターンをオプションと解釈して
# エラーで終了し、検出されなかった。大きな入力でも grep の起動を待たずに済む）
if ! cred_find_secret "$prompt"; then
  exit 0
fi
cred_reason "ユーザープロンプトに"
reason=$CRED_REASON

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
