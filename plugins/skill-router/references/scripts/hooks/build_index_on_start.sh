#!/usr/bin/env bash
# SessionStart hook entry for skill-router.
# Triggers build_index.py to refresh the routing index on startup / resume / clear.
#
# venv lifecycle (see references/scripts/lib/venv_lifecycle.py):
#   1. session-reset clears the previous session's rebuild counter so this
#      session has its full REBUILD_LIMIT (3) budget again.
#   2. ensure constructs the venv only when requirements.txt has active deps
#      (no-op while the plugin remains stdlib-only).
#   3. python-bin selects the venv python if available, else system python.
#   4. On a Python-traceback environment error (ModuleNotFoundError /
#      ImportError as the terminating exception), rebuild the venv up to
#      REBUILD_LIMIT times and retry once.
#
# Stale-venv teardown lives in route_prompt.sh (UserPromptSubmit) per the
# "check at the end of plugin activity" policy.
#
# Fail-open: any error must not block the session start.
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

if [[ -z "${PYTHON_BIN}" ]]; then
  exit 0
fi

LIFECYCLE="${PLUGIN_ROOT}/references/scripts/lib/venv_lifecycle.py"
TARGET="${PLUGIN_ROOT}/references/scripts/lib/build_index.py"
STDERR_FILE="$(mktemp -t skill-router-stderr.XXXXXX 2>/dev/null || echo "/tmp/skill-router-stderr.$$")"
trap 'rm -f "${STDERR_FILE}"' EXIT

"${PYTHON_BIN}" "${LIFECYCLE}" session-reset --plugin-root "${PLUGIN_ROOT}" >/dev/null 2>&1 || true
"${PYTHON_BIN}" "${LIFECYCLE}" ensure --plugin-root "${PLUGIN_ROOT}" >/dev/null 2>&1 || true

PY="$("${PYTHON_BIN}" "${LIFECYCLE}" python-bin --plugin-root "${PLUGIN_ROOT}" --no-construct 2>/dev/null || echo "${PYTHON_BIN}")"
[[ -z "${PY}" ]] && PY="${PYTHON_BIN}"

if ! "${PY}" "${TARGET}" >/dev/null 2>"${STDERR_FILE}"; then
  if "${PYTHON_BIN}" "${LIFECYCLE}" is-env-error --stderr-file "${STDERR_FILE}" >/dev/null 2>&1; then
    "${PYTHON_BIN}" "${LIFECYCLE}" rebuild --plugin-root "${PLUGIN_ROOT}" >/dev/null 2>&1 || true
    PY="$("${PYTHON_BIN}" "${LIFECYCLE}" python-bin --plugin-root "${PLUGIN_ROOT}" --no-construct 2>/dev/null || echo "${PYTHON_BIN}")"
    [[ -z "${PY}" ]] && PY="${PYTHON_BIN}"
    "${PY}" "${TARGET}" >/dev/null 2>&1 || true
  fi
fi

exit 0
