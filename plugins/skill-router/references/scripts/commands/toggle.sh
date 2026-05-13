#!/usr/bin/env bash
# Toggle skill-router routing on/off via the <base>/disabled flag file.
#
# Usage:
#   toggle.sh status   # print "skill-router: ON" or "skill-router: OFF" + exit 0
#   toggle.sh off      # create disabled flag at the highest-priority writable base
#   toggle.sh on       # remove disabled flag from every layer where it exists
#
# Resolution scopes (matches references/scripts/hooks/route_prompt.sh and
# references/scripts/commands/resolve_base.sh, kept in lock-step with the
# Python-side build_index.resolve_base_dir):
#   1. ${CLAUDE_PLUGIN_DATA}
#   2. <repo-root>/.claude/.local/plugins/skill-router/   (.git upward search)
#   3. <user-home>/.claude/.local/plugins/skill-router/
#
# Status check inspects all three layers (logical OR); off writes only to the
# highest-priority writable layer; on removes the flag from every layer it is
# present in. This keeps Bash and Python in agreement so a flag dropped by
# Python-side logic is honoured by the hook and vice-versa (architect H1/H2).
#
# Exit 0 always (fail-open): write failures are reported on stdout but do not
# block the surrounding /router-toggle command flow.

set -uo pipefail

ACTION="${1:-status}"

HOME_DIR="${HOME:-${USERPROFILE:-}}"

# Source resolve_base.sh so we share project_root / resolve_base with every
# other command and the hook.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=resolve_base.sh
source "${SCRIPT_DIR}/resolve_base.sh"

PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
HOME_BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"

# Compute the per-call repo base (may be empty if no .git ancestor exists).
REPO_BASE=""
if _repo="$(project_root)"; then
    REPO_BASE="${_repo}/.claude/.local/plugins/skill-router"
fi

_status() {
    if { [[ -n "${PLUGIN_DATA}" && -f "${PLUGIN_DATA}/disabled" ]]; } \
        || { [[ -n "${REPO_BASE}" && -f "${REPO_BASE}/disabled" ]]; } \
        || { [[ -n "${HOME_DIR}" && -f "${HOME_BASE}/disabled" ]]; }; then
        echo "skill-router: OFF"
    else
        echo "skill-router: ON"
    fi
}

_off() {
    local base
    base="$(resolve_base)"
    mkdir -p "${base}"
    touch "${base}/disabled"
    echo "skill-router toggled OFF (flag: ${base}/disabled)"
}

_on() {
    local removed=0
    for base in "${PLUGIN_DATA}" "${REPO_BASE}" "${HOME_BASE}"; do
        if [[ -n "${base}" && -f "${base}/disabled" ]]; then
            rm -f "${base}/disabled"
            echo "skill-router: removed disabled flag at ${base}/disabled"
            removed=$((removed + 1))
        fi
    done
    echo "skill-router toggled ON (cleared ${removed} flag(s))"
}

case "${ACTION}" in
    status) _status ;;
    off)    _off ;;
    on)     _on ;;
    *)      echo "skill-router: unknown action '${ACTION}' (expected: status|on|off)"; exit 0 ;;
esac

exit 0
