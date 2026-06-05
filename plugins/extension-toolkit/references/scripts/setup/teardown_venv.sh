#!/usr/bin/env bash
# teardown_venv.sh - venv 撤去 (Bash 版)
#
#
# 使い方: bash teardown_venv.sh <work_dir>
#         bash teardown_venv.sh -WorkDir <path>
set -euo pipefail

work_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -WorkDir|--work-dir) work_dir="${2:-}"; shift 2 ;;
    *)
      if [[ -z "$work_dir" ]]; then work_dir="$1"; fi
      shift ;;
  esac
done

if [[ -z "$work_dir" ]]; then
  echo "Usage: bash teardown_venv.sh -WorkDir <work_dir>" >&2
  exit 1
fi

venv_dir="$work_dir/.venv"

# 安全装置 1: パスを正規化
resolved_venv_dir=""
if [[ -e "$venv_dir" ]]; then
  resolved_venv_dir="$(cd "$(dirname -- "$venv_dir")" 2>/dev/null && pwd)/$(basename -- "$venv_dir")" || resolved_venv_dir="$venv_dir"
else
  resolved_venv_dir="$venv_dir"
fi

# シンボリックリンクの解決
if [[ -L "$resolved_venv_dir" ]]; then
  link_target="$(readlink -- "$resolved_venv_dir" 2>/dev/null || true)"
  if [[ -n "$link_target" ]]; then
    if [[ "$link_target" = /* ]]; then
      resolved_venv_dir="$link_target"
    else
      resolved_venv_dir="$(dirname -- "$resolved_venv_dir")/$link_target"
    fi
  fi
fi

normalized_path="${resolved_venv_dir//\\/\/}"

# 安全装置 2: .claude/.local/ 配下のみ削除を許可
if [[ "$normalized_path" != */.claude/.local/* ]]; then
  echo "[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete." >&2
  echo "  target (input): $venv_dir" >&2
  echo "  target (resolved): $resolved_venv_dir" >&2
  echo "  target (normalized): $normalized_path" >&2
  exit 1
fi

# 安全装置 3: システムルートパスを禁止 (.claude/.local/ を含むため通常は安全装置 2 で通過)
system_root_patterns=(
  '^/$'
  '^/root($|/)'
  '^/home($|/)'
  '^/etc($|/)'
  '^/usr($|/)'
  '^/var($|/)'
  '^/bin($|/)'
  '^/sbin($|/)'
  '^/opt($|/)'
  '^/Users($|/)'
  '^[A-Za-z]:/$'
)
for pattern in "${system_root_patterns[@]}"; do
  if [[ "$normalized_path" =~ $pattern && "$normalized_path" != */.claude/.local/* ]]; then
    echo "[teardown_venv] Error: refusing to operate on system path: $normalized_path" >&2
    exit 1
  fi
done

if [[ -d "$venv_dir" ]]; then
  rm -rf -- "$venv_dir"
  echo "[teardown_venv] Removed $venv_dir"
else
  echo "[teardown_venv] No venv at $venv_dir, nothing to do"
fi
