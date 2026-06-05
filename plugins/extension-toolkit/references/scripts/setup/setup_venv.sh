#!/usr/bin/env bash
# setup_venv.sh - extension-toolkit プラグイン共通 venv 構築 (Bash 版)
#
#
# 使い方:
#   bash setup_venv.sh <work_dir> [<requirements_path>] [<min_python_version>]
#   bash setup_venv.sh -WorkDir <path> [-RequirementsPath <path>] [-MinPythonVersion <X.Y>]
set -euo pipefail

work_dir=""
requirements_path=""
min_python_version=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -WorkDir|--work-dir)               work_dir="${2:-}"; shift 2 ;;
    -RequirementsPath|--requirements-path) requirements_path="${2:-}"; shift 2 ;;
    -MinPythonVersion|--min-python-version) min_python_version="${2:-}"; shift 2 ;;
    *)
      if [[ -z "$work_dir" ]]; then
        work_dir="$1"
      elif [[ -z "$requirements_path" ]]; then
        requirements_path="$1"
      elif [[ -z "$min_python_version" ]]; then
        min_python_version="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$work_dir" ]]; then
  echo "Usage: bash setup_venv.sh -WorkDir <work_dir> [-RequirementsPath <path>] [-MinPythonVersion <X.Y>]" >&2
  exit 1
fi

# WorkDir 正規化 + .claude/.local/ 配下チェック
resolved_work_dir="$(cd "$(dirname -- "$work_dir")" 2>/dev/null && pwd)/$(basename -- "$work_dir")" || resolved_work_dir="$work_dir"
normalized_work_dir="${resolved_work_dir//\\/\/}"
if [[ "$normalized_work_dir" != */.claude/.local/* ]]; then
  echo "[setup_venv] Error: work_dir is not under .claude/.local/, refusing to create venv." >&2
  echo "  target (input): $work_dir" >&2
  echo "  target (normalized): $normalized_work_dir" >&2
  exit 1
fi

venv_dir="$work_dir/.venv"

# Python コマンド検出
python_cmd=""
for candidate in python python3 py; do
  if "$candidate" -m venv --help >/dev/null 2>&1; then
    python_cmd="$candidate"
    break
  fi
done
if [[ -z "$python_cmd" ]]; then
  echo "[setup_venv] Error: python / python3 / py のいずれでも venv モジュールが利用できません" >&2
  exit 1
fi
echo "[setup_venv] Python コマンド: $python_cmd"

# MinPythonVersion チェック
if [[ -n "$min_python_version" ]]; then
  if ! [[ "$min_python_version" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "[setup_venv] Error: Invalid MIN_PYTHON_VERSION format: $min_python_version" >&2
    echo "  Expected format: X.Y or X.Y.Z (digits and dots only)" >&2
    exit 1
  fi
  actual_version="$("$python_cmd" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")"
  MIN_PYTHON_VERSION="$min_python_version" meets="$("$python_cmd" -c '
import os, sys
req = os.environ["MIN_PYTHON_VERSION"].split(".")
cur = (sys.version_info.major, sys.version_info.minor)
req_t = tuple(int(x) for x in req[:2]) if len(req) >= 2 else (int(req[0]), 0)
print("1" if cur >= req_t else "0")
')"
  if [[ "$meets" != "1" ]]; then
    echo "[setup_venv] Error: Python ${min_python_version}+ required, found ${actual_version}." >&2
    echo "  This script enforces fail-closed: install a newer Python or use pyenv to switch versions." >&2
    echo "  If continuation with the lower version is acceptable, the calling skill must" >&2
    echo "  obtain explicit user confirmation before invoking this script (see SKILL.md)." >&2
    exit 1
  fi
  echo "[setup_venv] Python $actual_version meets requirement (>= $min_python_version)"
fi

mkdir -p -- "$work_dir"

if [[ -d "$venv_dir" ]]; then
  echo "[setup_venv] venv already exists at $venv_dir, reusing"
else
  echo "[setup_venv] Creating venv at $venv_dir"
  if ! "$python_cmd" -m venv "$venv_dir"; then
    echo "[setup_venv] Error: venv creation failed" >&2
    exit 1
  fi
fi

# Python binary in venv
python=""
for c in "$venv_dir/Scripts/python.exe" "$venv_dir/Scripts/python" "$venv_dir/bin/python"; do
  if [[ -f "$c" ]]; then
    python="$c"
    break
  fi
done
if [[ -z "$python" ]]; then
  echo "[setup_venv] Error: Python binary not found in venv" >&2
  exit 1
fi

echo "[setup_venv] Upgrading pip / setuptools / wheel"
if ! "$python" -m pip install --upgrade pip setuptools wheel; then
  echo "[setup_venv] Error: pip upgrade failed" >&2
  exit 1
fi

if [[ -n "$requirements_path" ]]; then
  if [[ -f "$requirements_path" ]]; then
    echo "[setup_venv] Installing requirements from $requirements_path"
    if ! "$python" -m pip install -r "$requirements_path"; then
      echo "[setup_venv] Error: requirements install failed" >&2
      exit 1
    fi
  else
    echo "[setup_venv] Warning: $requirements_path not found, skipping" >&2
  fi
fi

echo "[setup_venv] Ready: $venv_dir"
python_version="$("$python" --version 2>&1)"
echo "[setup_venv] Python: $python_version"
