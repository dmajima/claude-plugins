#!/usr/bin/env bash
# meeting-minutes プラグイン venv 削除スクリプト (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: teardown_venv.ps1 （Git Bash 不調時等）
#
# PowerShell 版 (teardown_venv.ps1) と完全に同じメッセージ・終了コード・副作用を持つ。
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
