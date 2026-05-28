#!/usr/bin/env bash
# build_index_on_start.sh - SessionStart hook for skill-router (Bash 版)
#
# 通常運用は本スクリプトを利用する。PowerShell フォールバック: build_index_on_start.ps1
#
# venv ライフサイクル管理 (references/scripts/lib/venv_lifecycle.py):
#   session-reset → ensure → python-bin → build_index 実行
#   失敗時は env-error 判定 → rebuild → 再実行
#
# Fail-open: any error must not block the session start.

set +e

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
if [[ -z "$plugin_root" ]]; then
  script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  plugin_root="$(cd "$script_dir/../../.." && pwd)"
fi

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  python_bin="$(command -v python)"
fi
[[ -z "$python_bin" ]] && exit 0

lifecycle="$plugin_root/references/scripts/lib/venv_lifecycle.py"
target="$plugin_root/references/scripts/lib/build_index.py"

stderr_temp="$(mktemp 2>/dev/null || echo "/tmp/skill_router_build_$$")"
trap 'rm -f -- "$stderr_temp" 2>/dev/null || true' EXIT

"$python_bin" "$lifecycle" session-reset --plugin-root "$plugin_root" >/dev/null 2>&1
"$python_bin" "$lifecycle" ensure --plugin-root "$plugin_root" >/dev/null 2>&1

venv_py="$("$python_bin" "$lifecycle" python-bin --plugin-root "$plugin_root" --no-construct 2>/dev/null)"
[[ -z "${venv_py// /}" ]] && venv_py="$python_bin"

"$venv_py" "$target" >/dev/null 2>"$stderr_temp"
build_rc=$?

if [[ $build_rc -ne 0 ]]; then
  "$python_bin" "$lifecycle" is-env-error --stderr-file "$stderr_temp" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    "$python_bin" "$lifecycle" rebuild --plugin-root "$plugin_root" >/dev/null 2>&1
    venv_py="$("$python_bin" "$lifecycle" python-bin --plugin-root "$plugin_root" --no-construct 2>/dev/null)"
    [[ -z "${venv_py// /}" ]] && venv_py="$python_bin"
    "$venv_py" "$target" >/dev/null 2>&1 || true
  fi
fi

exit 0
