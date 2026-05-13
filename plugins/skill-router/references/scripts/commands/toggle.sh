#!/usr/bin/env bash
# Toggle skill-router routing on/off via the <base>/disabled flag file.
#
# Usage:
#   toggle.sh status   # print "skill-router: ON" or "skill-router: OFF" + exit 0
#   toggle.sh off      # create disabled flag at the highest-priority writable base
#   toggle.sh on       # remove disabled flag from every layer where it exists
#
# Resolution scopes (matches references/scripts/hooks/route_prompt.sh):
#   1. ${CLAUDE_PLUGIN_DATA}
#   2. <repo-root>/.claude/.local/plugins/skill-router/
#   3. <user-home>/.claude/.local/plugins/skill-router/
#
# Exit 0 always (fail-open): write failures are reported on stdout but do not
# block the surrounding /router-toggle command flow.

set -uo pipefail

ACTION="${1:-status}"

HOME_DIR="${HOME:-${USERPROFILE:-}}"
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
REPO_BASE="${PWD}/.claude/.local/plugins/skill-router"
HOME_BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"

_status() {
    if { [[ -n "${PLUGIN_DATA}" && -f "${PLUGIN_DATA}/disabled" ]]; } \
        || [[ -f "${REPO_BASE}/disabled" ]] \
        || { [[ -n "${HOME_DIR}" && -f "${HOME_BASE}/disabled" ]]; }; then
        echo "skill-router: OFF"
    else
        echo "skill-router: ON"
    fi
}

_off() {
    if [[ -n "${PLUGIN_DATA}" ]]; then
        BASE="${PLUGIN_DATA}"
    elif [[ -d "${PWD}/.claude" ]]; then
        BASE="${REPO_BASE}"
    else
        BASE="${HOME_BASE}"
    fi
    mkdir -p "${BASE}"
    touch "${BASE}/disabled"
    echo "skill-router toggled OFF (flag: ${BASE}/disabled)"
}

_on() {
    for BASE in "${PLUGIN_DATA}" "${REPO_BASE}" "${HOME_BASE}"; do
        if [[ -n "${BASE}" && -f "${BASE}/disabled" ]]; then
            rm -f "${BASE}/disabled"
            echo "skill-router: removed disabled flag at ${BASE}/disabled"
        fi
    done
    echo "skill-router toggled ON"
}

case "${ACTION}" in
    status) _status ;;
    off)    _off ;;
    on)     _on ;;
    *)      echo "skill-router: unknown action '${ACTION}' (expected: status|on|off)"; exit 0 ;;
esac

exit 0
