#!/usr/bin/env bash
# teardown_venv.sh - skill-router プラグイン venv 撤去 (Bash 版)
#
# 通常運用は本スクリプトを利用する。PowerShell フォールバック: teardown_venv.ps1
#
# 使い方: bash teardown_venv.sh <work_dir>
#         bash teardown_venv.sh -WorkDir <path>
set -euo pipefail

work_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -WorkDir|--work-dir) work_dir="${2:-}"; shift 2 ;;
    *) [[ -z "$work_dir" ]] && work_dir="$1"; shift ;;
  esac
done

if [[ -z "$work_dir" ]]; then
  echo "Usage: bash teardown_venv.sh -WorkDir <work_dir>" >&2
  exit 1
fi

venv_dir="$work_dir/.venv"

# 安全装置: パス正規化
resolved_venv_dir=""
if [[ -e "$venv_dir" ]]; then
  resolved_venv_dir="$(cd "$(dirname -- "$venv_dir")" 2>/dev/null && pwd)/$(basename -- "$venv_dir")"
else
  resolved_venv_dir="$venv_dir"
fi
normalized_path="${resolved_venv_dir//\\/\/}"

# .claude/.local/ 配下のみ削除を許可
if [[ "$normalized_path" != */.claude/.local/* ]]; then
  echo "[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete." >&2
  echo "  target (input): $venv_dir" >&2
  echo "  target (resolved): $resolved_venv_dir" >&2
  echo "  target (normalized): $normalized_path" >&2
  exit 1
fi

if [[ -d "$venv_dir" ]]; then
  rm -rf -- "$venv_dir"
  echo "[teardown_venv] Removed $venv_dir"
else
  echo "[teardown_venv] No venv at $venv_dir, nothing to do"
fi
