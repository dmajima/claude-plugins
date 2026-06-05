#!/usr/bin/env bash
# meeting-minutes プラグイン venv 削除スクリプト (Bash 版)
#
#
#
# 使い方:
#   bash teardown_venv.sh <work_dir>
set -euo pipefail

work_dir="${1:-}"
if [[ -z "$work_dir" ]]; then
  echo "[teardown_venv] ERROR: <work_dir> is required." >&2
  echo "Usage: $0 <work_dir>" >&2
  exit 2
fi

venv_dir="$work_dir/.venv"

if [[ -d "$venv_dir" ]]; then
  echo "[teardown_venv] Removing venv: $venv_dir"
  rm -rf -- "$venv_dir"
  echo "[teardown_venv] Done."
else
  echo "[teardown_venv] No venv found at: $venv_dir"
fi
