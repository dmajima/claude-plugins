#!/usr/bin/env bash
# check_version_bump_on_commit.sh - PreToolUse Bash|PowerShell フック (Bash 版)
#
#
# `git commit ...` 直前に check_version_bump.sh を呼び出し、
# バージョン未更新のプラグインがある場合は additionalContext で警告する。
# 設計: フェイルオープン

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stdin="$(cat)"
[[ -z "${stdin//[[:space:]]/}" ]] && exit 0

tool_name="$(printf '%s' "$stdin" | jq -er '.tool_name // empty' 2>/dev/null)"
# Bash と PowerShell の両方を受け入れる
[[ "$tool_name" != "Bash" && "$tool_name" != "PowerShell" ]] && exit 0

cmd="$(printf '%s' "$stdin" | jq -er '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$cmd" ]] && exit 0

if ! [[ "$cmd" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
delegate="$script_dir/check_version_bump.sh"
[[ ! -f "$delegate" ]] && exit 0

# 委譲スクリプトの stderr を捕捉して additionalContext に変換
warnings="$(printf '%s' '{}' | bash "$delegate" 2>&1)"

if [[ -n "${warnings//[[:space:]]/}" ]]; then
  # additionalContext として stdout に JSON 出力（Claude に警告を届ける）
  jq -n --arg ctx "$warnings" '{"additionalContext": $ctx}'
fi

exit 0
