#!/usr/bin/env bash
# SessionStart hook entry for skill-router.
# Triggers build_index.py to refresh the routing index on startup / resume / clear.
# Fail-open: any error must not block the session start.
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
PYTHON_BIN="$(command -v python3 || command -v python || true)"

if [[ -z "${PYTHON_BIN}" ]]; then
  exit 0
fi

"${PYTHON_BIN}" "${PLUGIN_ROOT}/references/scripts/lib/build_index.py" >/dev/null 2>&1 || true
exit 0
