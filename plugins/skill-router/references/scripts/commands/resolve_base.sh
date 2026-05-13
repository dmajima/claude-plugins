#!/usr/bin/env bash
# Resolve skill-router <base> directory and echo it on stdout.
#
# Resolution order (kept in lock-step with build_index.resolve_base_dir
# in references/scripts/lib/build_index.py so Bash callers and Python
# callers always agree on the same <base>):
#
#   1. ${CLAUDE_PLUGIN_DATA}                                    (plugin data dir)
#   2. <repo-root>/.claude/.local/plugins/skill-router/         (walk parents
#                                                                from $PWD
#                                                                looking for
#                                                                .git, mirror
#                                                                of Python
#                                                                _project_root)
#   3. <user-home>/.claude/.local/plugins/skill-router/         (user scope)
#
# Used by /router-status, /router-toggle, /router-embedding-cache and the
# UserPromptSubmit hook (route_prompt.sh sources this script for the
# project_base() helper) so that the command markdown files do not embed
# control-flow inline (ADR-025 / scripts-policy) and so the Bash-side
# resolution stays consistent with the Python-side one (architect H1/H2).
#
# Exit 0 always: the resolved path is best-effort. Callers must check existence.

set -uo pipefail

HOME_DIR="${HOME:-${USERPROFILE:-}}"

# Walk up from $PWD looking for a .git entry (file or dir for git worktrees).
# Stops at filesystem root or HOME so a stray .git in a parent of HOME does
# not leak into unrelated sessions. Echoes nothing when no repo root is found.
project_root() {
    local dir="${1:-$PWD}"
    # Limit walk to HOME so we never escape the user's tree.
    local stop_at="${HOME_DIR%/}"
    while [[ -n "${dir}" && "${dir}" != "/" && "${dir}" != "." ]]; do
        if [[ -e "${dir}/.git" ]]; then
            echo "${dir}"
            return 0
        fi
        if [[ -n "${stop_at}" && "${dir}" == "${stop_at}" ]]; then
            return 1
        fi
        local parent
        parent="$(dirname "${dir}")"
        if [[ "${parent}" == "${dir}" ]]; then
            return 1
        fi
        dir="${parent}"
    done
    return 1
}

# Resolve the <base> directory. Side-effect free; returns one of three paths.
resolve_base() {
    if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
        echo "${CLAUDE_PLUGIN_DATA}"
        return 0
    fi
    local repo
    if repo="$(project_root)"; then
        echo "${repo}/.claude/.local/plugins/skill-router"
        return 0
    fi
    echo "${HOME_DIR}/.claude/.local/plugins/skill-router"
}

# Echo the resolved <base> when invoked directly (and not just sourced).
# BASH_SOURCE[0] differs from $0 when this file is sourced.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    resolve_base
fi
