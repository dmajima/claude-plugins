#!/usr/bin/env bash
# check_version_bump_on_commit.sh - PreToolUse Bash フック (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: check_version_bump_on_commit.ps1
#
# `git commit ...` 直前に check_version_bump.sh を呼び出し、
# バージョン未更新のプラグインがある場合は警告する。
# 設計: フェイルオープン

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

stdin="$(cat)"
[[ -z "${stdin//[[:space:]]/}" ]] && exit 0

tool_name="$(printf '%s' "$stdin" | jq -er '.tool_name // empty' 2>/dev/null)"
[[ "$tool_name" != "Bash" ]] && exit 0

cmd="$(printf '%s' "$stdin" | jq -er '.tool_input.command // empty' 2>/dev/null)"
[[ -z "$cmd" ]] && exit 0

if ! [[ "$cmd" =~ git[[:space:]]+commit ]]; then
  exit 0
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
delegate="$script_dir/check_version_bump.sh"
[[ ! -f "$delegate" ]] && exit 0

# 委譲スクリプトに空 JSON を渡す
printf '%s' '{}' | bash "$delegate" || true

exit 0
