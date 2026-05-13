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
# Why no rebuild here: the 10s UserPromptSubmit budget cannot accommodate
# venv create (60s) + pip install (180s).  If route.py raises an env
# error during this hook, it surfaces as an exit-non-zero from the python
# call below; the next SessionStart will pick it up via its own
# ensure/rebuild path.  Operators forced to recover mid-session can run
# `/router-rebuild` (which delegates to build_index_on_start.sh) without
# waiting for SessionStart.
#
# Fail-open: any error must not block the user prompt.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"

# Windows compatibility: when running under Git Bash / MSYS / Cygwin,
# ${CLAUDE_PLUGIN_ROOT} may arrive as a POSIX-form path like
# "/c/Users/<user>/.claude/...".  Windows-native python.exe cannot parse that
# form and interprets the leading "/c/" as a literal "\c\" directory beneath
# the current drive root, producing
#   "C:\c\Users\<user>\.claude\..."  →  ENOENT.
# Convert to the "mixed" form ("C:/Users/...") with cygpath -m, which is
# interpretable by both Bash (for source/dirname/etc.) and native Python
# (for argv path resolution).  cygpath is absent on Linux/macOS, where the
# conversion is correctly skipped.
if command -v cygpath >/dev/null 2>&1; then
    PLUGIN_ROOT="$(cygpath -m "${PLUGIN_ROOT}" 2>/dev/null || echo "${PLUGIN_ROOT}")"
fi

PYTHON_BIN="$(command -v python3 || command -v python || true)"

INPUT="$(cat)"

if [[ -z "${PYTHON_BIN}" ]]; then
  exit 0
fi

# Toggle check. Resolution order matches build_index.resolve_base_dir
# (Python) and references/scripts/commands/resolve_base.sh (Bash CLI):
#   1. CLAUDE_PLUGIN_DATA/disabled                        (if set)
#   2. <repo-root>/.claude/.local/plugins/skill-router/disabled
#                                                         (.git upward search)
#   3. <user-home>/.claude/.local/plugins/skill-router/disabled
#                                                         (last resort)
# Disabled flag at *any* layer disables routing (logical OR), matching the
# /router-toggle status / on / off semantics and avoiding the Python/Bash
# inconsistency raised by architect H1/H2.
# Windows compatibility: HOME may be unset; fall back to USERPROFILE.
HOME_DIR="${HOME:-${USERPROFILE:-}}"

# shellcheck source=../commands/resolve_base.sh
source "${PLUGIN_ROOT}/references/scripts/commands/resolve_base.sh"

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/disabled" ]]; then
  exit 0
fi
if _repo="$(project_root)"; then
  if [[ -f "${_repo}/.claude/.local/plugins/skill-router/disabled" ]]; then
    exit 0
  fi
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
