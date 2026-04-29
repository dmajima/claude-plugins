#!/bin/bash
# venv 構築スクリプト（プラグイン横断）
# 使い方: bash setup_venv.sh <work_dir> [<requirements_path>]
#   <work_dir> 配下に .venv を作成し、requirements.txt があればインストール

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir> [<requirements_path>]" >&2
  exit 1
fi

WORK_DIR="$1"
REQUIREMENTS_PATH="${2:-}"
VENV_DIR="${WORK_DIR}/.venv"

mkdir -p "${WORK_DIR}"

if [ -d "${VENV_DIR}" ]; then
  echo "[setup_venv] venv already exists at ${VENV_DIR}, reusing"
else
  echo "[setup_venv] Creating venv at ${VENV_DIR}"
  python -m venv "${VENV_DIR}"
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
