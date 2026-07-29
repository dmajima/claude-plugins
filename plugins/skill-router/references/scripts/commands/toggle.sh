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

# 階層の知識はこのスクリプトに持たない。フックの判定（skill_router_is_disabled）
# と探索リスト（skill_router_disabled_candidates）を resolve_base.sh から共有する。
# ここで判定を書き直すと、正規化の有無が食い違って「OFF にしたのに status は ON、
# on にしても復帰しない」という無音の不整合になる。
invoke_status() {
  if skill_router_is_disabled; then
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
  while IFS= read -r base; do
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
  done < <(skill_router_disabled_candidates)
  echo "skill-router toggled ON (cleared $removed flag(s))"
}

case "${action,,}" in
  status) invoke_status ;;
  off)    invoke_off ;;
  on)     invoke_on ;;
  *)      echo "skill-router: unknown action '$action' (expected: status|on|off)" ;;
esac

exit 0
