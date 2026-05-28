#!/usr/bin/env bash
# convert-doc プラグイン共通 venv 構築スクリプト (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: setup_venv.ps1 （Git Bash 不調時等）
#
# PowerShell 版 (setup_venv.ps1) と完全に同じメッセージ・終了コード・副作用を持つ。
#
# 使い方:
#   bash setup_venv.sh <work_dir> [<requirements_path>]
#   bash setup_venv.sh -WorkDir <path> [-RequirementsPath <path>]
set -euo pipefail

work_dir=""
requirements_path=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -WorkDir|--work-dir)
      work_dir="${2:-}"; shift 2 ;;
    -RequirementsPath|--requirements-path)
      requirements_path="${2:-}"; shift 2 ;;
    *)
      if [[ -z "$work_dir" ]]; then
        work_dir="$1"
      elif [[ -z "$requirements_path" ]]; then
        requirements_path="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$work_dir" ]]; then
  echo "Usage: $0 <work_dir> [<requirements_path>]" >&2
  exit 2
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$work_dir" ]]; then
  mkdir -p -- "$work_dir"
fi

venv_path="$work_dir/.venv"

if [[ ! -d "$venv_path" ]]; then
  echo "[OK] Creating venv at $venv_path"
  if ! python -m venv "$venv_path"; then
    echo "Failed to create venv at $venv_path" >&2
    exit 1
  fi
fi

# venv の python.exe / python を解決（Windows / Unix 両対応）
python_exe=""
if [[ -f "$venv_path/Scripts/python.exe" ]]; then
  python_exe="$venv_path/Scripts/python.exe"
elif [[ -f "$venv_path/bin/python" ]]; then
  python_exe="$venv_path/bin/python"
else
  echo "venv python not found at $venv_path" >&2
  exit 1
fi

if [[ -z "$requirements_path" ]]; then
  requirements_path="$script_dir/requirements.txt"
fi

if [[ -f "$requirements_path" ]]; then
  echo "[OK] Installing requirements from $requirements_path"
  if ! "$python_exe" -m pip install --quiet --upgrade pip; then
    echo "pip upgrade failed" >&2
    exit 1
  fi
  if ! "$python_exe" -m pip install --quiet -r "$requirements_path"; then
    echo "pip install failed" >&2
    exit 1
  fi
else
  echo "[WARN] requirements.txt not found at $requirements_path"
fi

echo "[DONE] venv ready: $venv_path"
