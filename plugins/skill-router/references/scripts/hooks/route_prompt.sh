#!/usr/bin/env bash
# UserPromptSubmit hook entry for skill-router.
# CRITICAL (D2 / C3): NEVER parse stdin JSON in Bash. Always delegate to Python (json.load).
# Bash responsibilities are limited to:
#   1. Spawning the Python interpreter.
#   2. Checking the toggle (disabled) file.
#   3. Passing stdin through unchanged.
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

printf '%s' "${INPUT}" | "${PYTHON_BIN}" "${PLUGIN_ROOT}/references/scripts/lib/route.py"
exit 0
