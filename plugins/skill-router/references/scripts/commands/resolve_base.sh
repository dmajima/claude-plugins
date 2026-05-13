#!/usr/bin/env bash
# Resolve skill-router <base> directory and echo it on stdout.
#
# Resolution order (matches references/scripts/hooks/route_prompt.sh):
#   1. ${CLAUDE_PLUGIN_DATA}                                    (plugin data dir)
#   2. <repo-root>/.claude/.local/plugins/skill-router/         (repository scope)
#   3. <user-home>/.claude/.local/plugins/skill-router/         (user scope)
#
# Used by /router-status, /router-toggle, /router-embedding-cache so that the
# command markdown files do not embed control-flow inline (ADR-025 / scripts-policy).
#
# Exit 0 always: the resolved path is best-effort. Callers must check existence.

set -uo pipefail

HOME_DIR="${HOME:-${USERPROFILE:-}}"

if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -d "${CLAUDE_PLUGIN_DATA}" ]]; then
    BASE="${CLAUDE_PLUGIN_DATA}"
elif [[ -d "${PWD}/.claude/.local/plugins/skill-router" ]]; then
    BASE="${PWD}/.claude/.local/plugins/skill-router"
else
    BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"
fi

echo "${BASE}"
