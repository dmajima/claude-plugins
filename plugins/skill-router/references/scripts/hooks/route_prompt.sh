#!/usr/bin/env bash
# route_prompt.sh - UserPromptSubmit hook for skill-router (Bash 版)
#
# 通常運用は本スクリプトを利用する。PowerShell フォールバック: route_prompt.ps1
#
# CRITICAL: stdin JSON は Bash で parse せず、Python (json.load) に委譲する。
# Bash の責務は: Python interpreter の起動 / toggle (disabled) check / stdin の素通し のみ。
#
# Fail-open: any error must not block the user prompt.

set +e

# stdin を最初に読み取って保持
stdin_payload="$(cat)"

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

# Toggle check
# shellcheck source=../commands/resolve_base.sh
source "$plugin_root/references/scripts/commands/resolve_base.sh"

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/disabled" ]]; then
  exit 0
fi

repo="$(skill_router_project_root 2>/dev/null || true)"
if [[ -n "$repo" && -f "$repo/.claude/.local/plugins/skill-router/disabled" ]]; then
  exit 0
fi

home_dir="$(skill_router_home_dir)"
if [[ -n "$home_dir" && -f "$home_dir/.claude/.local/plugins/skill-router/disabled" ]]; then
  exit 0
fi

lifecycle="$plugin_root/references/scripts/lib/venv_lifecycle.py"
venv_py="$("$python_bin" "$lifecycle" python-bin --plugin-root "$plugin_root" --no-construct 2>/dev/null)"
[[ -z "${venv_py// /}" ]] && venv_py="$python_bin"

route_script="$plugin_root/references/scripts/lib/route.py"

# Python に stdin を渡して起動。Bash の I/O リダイレクトで stdin/stdout/stderr を制御。
# .NET Process API のような複雑な処理は不要 (Bash の pipe で完結)。
printf '%s' "$stdin_payload" | "$venv_py" "$route_script"
route_rc=$?

# Stale-venv teardown (routing 完了後)
"$python_bin" "$lifecycle" cleanup-if-stale --plugin-root "$plugin_root" >/dev/null 2>&1

exit $route_rc
