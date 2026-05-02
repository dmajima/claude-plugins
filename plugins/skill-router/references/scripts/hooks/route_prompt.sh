#!/usr/bin/env bash
# UserPromptSubmit hook entry for skill-router.
# CRITICAL (D2 / C3): NEVER parse stdin JSON in Bash. Always delegate to Python (json.load).
# Bash responsibilities are limited to:
#   1. Spawning the Python interpreter.
#   2. Checking the toggle (disabled) file.
#   3. Passing stdin through unchanged.
#
# venv lifecycle: this hook *consumes* an existing venv (no construction
# or rebuild here -- SessionStart owns those) and runs cleanup-if-stale at
# the very end so a venv older than 72h is removed once the plugin's
# user-facing activity finishes.  Stale check is O(stat) and well within
# the 10s timeout.
#
# Fail-open: any error must not block the user prompt.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PYTHON_BIN="$(command -v python3 || command -v python || true)"

INPUT="$(cat)"

if [[ -z "${PYTHON_BIN}" ]]; then
  exit 0
fi

# Toggle check. Resolution order matches design v2 section 4.4:
#   1. CLAUDE_PLUGIN_DATA/disabled   (if the variable is provided)
#   2. <pwd>/.claude/.local/plugins/skill-router/disabled  (repository scope)
#   3. <user-home>/.claude/.local/plugins/skill-router/disabled (user scope, last resort)
# Windows compatibility: HOME may be unset; fall back to USERPROFILE.
HOME_DIR="${HOME:-${USERPROFILE:-}}"

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/disabled" ]]; then
  exit 0
fi
if [[ -f "${PWD}/.claude/.local/plugins/skill-router/disabled" ]]; then
  exit 0
fi
if [[ -n "${HOME_DIR}" && -f "${HOME_DIR}/.claude/.local/plugins/skill-router/disabled" ]]; then
  exit 0
fi

LIFECYCLE="${PLUGIN_ROOT}/references/scripts/lib/venv_lifecycle.py"
PY="$("${PYTHON_BIN}" "${LIFECYCLE}" python-bin --plugin-root "${PLUGIN_ROOT}" --no-construct 2>/dev/null || echo "${PYTHON_BIN}")"
[[ -z "${PY}" ]] && PY="${PYTHON_BIN}"

printf '%s' "${INPUT}" | "${PY}" "${PLUGIN_ROOT}/references/scripts/lib/route.py"
ROUTE_RC=$?

# Stale-venv teardown (Q3): runs after the routing call so the user-facing
# response is never delayed by the cleanup.
"${PYTHON_BIN}" "${LIFECYCLE}" cleanup-if-stale --plugin-root "${PLUGIN_ROOT}" >/dev/null 2>&1 || true

exit "${ROUTE_RC}"
