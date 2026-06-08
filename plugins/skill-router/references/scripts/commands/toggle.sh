#!/usr/bin/env bash
# toggle.sh - Toggle skill-router routing on/off (Bash 版)
#
#
# Usage:
#   bash toggle.sh status   # print "skill-router: ON" or "skill-router: OFF"
#   bash toggle.sh off      # create disabled flag at the highest-priority writable base
#   bash toggle.sh on       # remove disabled flag from every layer where it exists

# shellcheck source=resolve_base.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/resolve_base.sh"

action="${1:-status}"

plugin_data="${CLAUDE_PLUGIN_DATA:-}"
home_dir="$(skill_router_home_dir)"
home_base=""
[[ -n "$home_dir" ]] && home_base="$home_dir/.claude/.local/plugins/skill-router"

repo_base=""
if repo="$(skill_router_project_root)"; then
  repo_base="$repo/.claude/.local/plugins/skill-router"
fi

test_disabled_flag() {
  local base="$1"
  [[ -z "$base" ]] && return 1
  [[ -f "$base/disabled" ]]
}

invoke_status() {
  if test_disabled_flag "$plugin_data" || test_disabled_flag "$repo_base" || test_disabled_flag "$home_base"; then
    echo "skill-router: OFF"
  else
    echo "skill-router: ON"
  fi
}

invoke_off() {
  local base
  base="$(skill_router_base)"
  if [[ -z "$base" ]]; then
    echo "skill-router: failed to resolve base directory"
    return
  fi
  if ! mkdir -p -- "$base" 2>/dev/null; then
    echo "skill-router: failed to write disabled flag at $base/disabled"
    return
  fi
  local flag_path="$base/disabled"
  if [[ ! -f "$flag_path" ]]; then
    : > "$flag_path" 2>/dev/null || { echo "skill-router: failed to write disabled flag at $flag_path"; return; }
  else
    touch -- "$flag_path" 2>/dev/null || true
  fi
  echo "skill-router toggled OFF (flag: $base/disabled)"
}

invoke_on() {
  local removed=0 base flag_path
  for base in "$plugin_data" "$repo_base" "$home_base"; do
    [[ -z "$base" ]] && continue
    flag_path="$base/disabled"
    if [[ -f "$flag_path" ]]; then
      if rm -f -- "$flag_path" 2>/dev/null; then
        echo "skill-router: removed disabled flag at $flag_path"
        removed=$((removed + 1))
      else
        echo "skill-router: failed to remove disabled flag at $flag_path"
      fi
    fi
  done
  echo "skill-router toggled ON (cleared $removed flag(s))"
}

case "${action,,}" in
  status) invoke_status ;;
  off)    invoke_off ;;
  on)     invoke_on ;;
  *)      echo "skill-router: unknown action '$action' (expected: status|on|off)" ;;
esac

exit 0
