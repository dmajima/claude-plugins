#!/usr/bin/env bash
# deep-test プラグイン共通 venv 構築スクリプト (Bash 版)
#
# セッション作業領域 <work_dir>/.venv に venv を作成し、
# $SCRIPT_DIR/requirements.txt（プラグイン共通の依存定義）を自動参照してインストールする。
# プラグイン内の全スキル（test / test-report / test-setup 等）が本スクリプトを共用する。
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

# python コマンド不在時は python3 へフォールバック（Unix 系では python3 のみの環境がある）
command -v python >/dev/null 2>&1 && PY=python || PY=python3
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "python / python3 のいずれも見つかりません（Python 3.9+ を導入してください）" >&2
  exit 1
fi

if [[ ! -d "$venv_path" ]]; then
  echo "[OK] Creating venv at $venv_path (interpreter: $PY)"
  if ! "$PY" -m venv "$venv_path"; then
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
