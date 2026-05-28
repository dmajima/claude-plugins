#!/usr/bin/env bash
# meeting-minutes プラグイン共通 venv 構築スクリプト (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: setup_venv.ps1 （Git Bash 不調時等）
#
# PowerShell 版 (setup_venv.ps1) と完全に同じメッセージ・終了コード・副作用を持つ。
#
# 使い方:
#   bash setup_venv.sh <work_dir>
set -euo pipefail

work_dir="${1:-}"
if [[ -z "$work_dir" ]]; then
  echo "[setup_venv] ERROR: <work_dir> is required." >&2
  echo "Usage: $0 <work_dir>" >&2
  exit 2
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
venv_dir="$work_dir/.venv"

python_cmd=""
for candidate in python python3 py; do
  if command -v "$candidate" >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
if [[ -z "$python_cmd" ]]; then
  echo "[setup_venv] ERROR: python not found. Install Python 3.10+ first." >&2
  exit 1
fi

if [[ -d "$venv_dir" ]]; then
  echo "[setup_venv] venv already exists: $venv_dir"
else
  echo "[setup_venv] Creating venv: $venv_dir (using $python_cmd)"
  "$python_cmd" -m venv "$venv_dir"
fi

if [[ -f "$venv_dir/Scripts/pip.exe" ]]; then
  pip="$venv_dir/Scripts/pip.exe"
elif [[ -f "$venv_dir/bin/pip" ]]; then
  pip="$venv_dir/bin/pip"
else
  echo "[setup_venv] ERROR: pip not found in venv" >&2
  exit 1
fi

req="$script_dir/requirements.txt"
echo "[setup_venv] Installing packages from: $req"
"$pip" install -r "$req" --quiet

echo "[setup_venv] Done."
