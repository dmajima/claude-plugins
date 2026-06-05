#!/usr/bin/env bash
# resolve_base.sh - Resolve skill-router <base> directory (Bash 版)
#
#
# Resolution order (build_index.resolve_base_dir と lock-step):
#   1. ${CLAUDE_PLUGIN_DATA}
#   2. <repo-root>/.claude/.local/plugins/skill-router/  (walk parents from PWD looking for .git)
#   3. <user-home>/.claude/.local/plugins/skill-router/
#
# 使い方:
#   source resolve_base.sh  → 関数を import
#   bash resolve_base.sh    → resolved base を stdout に出力

skill_router_home_dir() {
  if [[ -n "${USERPROFILE:-}" ]]; then printf '%s' "$USERPROFILE"
  elif [[ -n "${HOME:-}" ]]; then printf '%s' "$HOME"
  fi
}

skill_router_project_root() {
  local dir="${1:-$PWD}"
  local home_dir trimmed parent
  home_dir="$(skill_router_home_dir)"
  home_dir="${home_dir%/}"
  home_dir="${home_dir%\\}"

  while [[ -n "$dir" ]]; do
    trimmed="${dir%/}"
    trimmed="${trimmed%\\}"
    if [[ -z "$trimmed" || "$trimmed" == "." ]]; then return 1; fi

    if [[ -e "$dir/.git" ]]; then printf '%s' "$dir"; return 0; fi
    if [[ -n "$home_dir" && "$trimmed" == "$home_dir" ]]; then return 1; fi

    parent="$(dirname -- "$dir")"
    if [[ -z "$parent" || "$parent" == "$dir" ]]; then return 1; fi
    dir="$parent"
  done
  return 1
}

skill_router_base() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then printf '%s' "$CLAUDE_PLUGIN_DATA"; return; fi
  local repo home_dir
  if repo="$(skill_router_project_root)"; then
    printf '%s' "$repo/.claude/.local/plugins/skill-router"; return
  fi
  home_dir="$(skill_router_home_dir)"
  if [[ -n "$home_dir" ]]; then
    printf '%s' "$home_dir/.claude/.local/plugins/skill-router"; return
  fi
}

# Direct invocation: echo the resolved base
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  base="$(skill_router_base)"
  [[ -n "$base" ]] && printf '%s\n' "$base"
fi
