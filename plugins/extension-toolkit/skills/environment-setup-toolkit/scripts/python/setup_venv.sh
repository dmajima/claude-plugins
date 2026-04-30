#!/bin/bash
# venv 構築スクリプト（プラグイン横断）
# 使い方: bash setup_venv.sh <work_dir> [<requirements_path>] [<min_python_version>]
#   <work_dir> 配下に .venv を作成し、requirements.txt があればインストール
#   <min_python_version> 指定時、システム Python のバージョン要件を検証（例: 3.10）
#
# セキュリティ: <min_python_version> はバリデーション後に環境変数経由で Python に渡す
# （bash 文字列補間によるコード注入を排除）

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir> [<requirements_path>] [<min_python_version>]" >&2
  exit 1
fi

WORK_DIR="$1"
REQUIREMENTS_PATH="${2:-}"
MIN_PYTHON_VERSION="${3:-}"
VENV_DIR="${WORK_DIR}/.venv"

# Python コマンド検出（python3 優先、フォールバックで python）
PYTHON_CMD=""
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  echo "[setup_venv] Error: python3/python not found in PATH." >&2
  exit 1
fi

# 1. システム Python のバージョン要件チェック（指定時のみ、fail-closed）
if [ -n "${MIN_PYTHON_VERSION}" ]; then
  # 引数バリデーション: 数値とドットのみ許容（例: 3.10, 3.11.2）
  if ! [[ "${MIN_PYTHON_VERSION}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "[setup_venv] Error: Invalid MIN_PYTHON_VERSION format: ${MIN_PYTHON_VERSION}" >&2
    echo "  Expected format: X.Y or X.Y.Z (digits and dots only)" >&2
    exit 1
  fi
  ACTUAL_VERSION=$("${PYTHON_CMD}" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
  # 環境変数経由で Python に渡す（bash 文字列補間を排除）
  MEETS=$(MIN_PYTHON_VERSION="${MIN_PYTHON_VERSION}" "${PYTHON_CMD}" -c '
import os, sys
req = os.environ["MIN_PYTHON_VERSION"].split(".")
cur = (sys.version_info.major, sys.version_info.minor)
req_t = tuple(int(x) for x in req[:2]) if len(req) >= 2 else (int(req[0]), 0)
print("1" if cur >= req_t else "0")
' 2>/dev/null || echo "0")
  if [ "${MEETS}" != "1" ]; then
    echo "[setup_venv] Error: Python ${MIN_PYTHON_VERSION}+ required, found ${ACTUAL_VERSION}." >&2
    echo "  This script enforces fail-closed: install a newer Python or use pyenv to switch versions." >&2
    echo "  If continuation with the lower version is acceptable, the calling skill must" >&2
    echo "  obtain explicit user confirmation before invoking this script (see SKILL.md)." >&2
    exit 1
  fi
  echo "[setup_venv] Python ${ACTUAL_VERSION} meets requirement (>= ${MIN_PYTHON_VERSION})"
fi

mkdir -p "${WORK_DIR}"

if [ -d "${VENV_DIR}" ]; then
  echo "[setup_venv] venv already exists at ${VENV_DIR}, reusing"
else
  echo "[setup_venv] Creating venv at ${VENV_DIR}"
  "${PYTHON_CMD}" -m venv "${VENV_DIR}"
fi

if [ -f "${VENV_DIR}/Scripts/python" ] || [ -f "${VENV_DIR}/Scripts/python.exe" ]; then
  PYTHON="${VENV_DIR}/Scripts/python"
elif [ -f "${VENV_DIR}/bin/python" ]; then
  PYTHON="${VENV_DIR}/bin/python"
else
  echo "[setup_venv] Error: Python binary not found in venv" >&2
  exit 1
fi

echo "[setup_venv] Upgrading pip / setuptools / wheel"
"${PYTHON}" -m pip install --upgrade pip setuptools wheel

if [ -n "${REQUIREMENTS_PATH}" ]; then
  if [ -f "${REQUIREMENTS_PATH}" ]; then
    echo "[setup_venv] Installing requirements from ${REQUIREMENTS_PATH}"
    "${PYTHON}" -m pip install -r "${REQUIREMENTS_PATH}"
  else
    echo "[setup_venv] Warning: ${REQUIREMENTS_PATH} not found, skipping" >&2
  fi
fi

echo "[setup_venv] Ready: ${VENV_DIR}"
echo "[setup_venv] Python: $(${PYTHON} --version)"
