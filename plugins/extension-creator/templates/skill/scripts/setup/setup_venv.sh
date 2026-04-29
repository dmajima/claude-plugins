#!/bin/bash
# venv 構築スクリプト（テンプレート）
# 使い方: bash setup_venv.sh <work_dir>
#   <work_dir> 配下に .venv を作成し、requirements.txt をインストールする

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir>" >&2
  exit 1
fi

WORK_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${WORK_DIR}/.venv"

mkdir -p "${WORK_DIR}"

if [ -d "${VENV_DIR}" ]; then
  echo "venv already exists at ${VENV_DIR}, reusing"
else
  echo "Creating venv at ${VENV_DIR}"
  python -m venv "${VENV_DIR}"
fi

if [ -f "${VENV_DIR}/Scripts/python" ]; then
  PYTHON="${VENV_DIR}/Scripts/python"
else
  PYTHON="${VENV_DIR}/bin/python"
fi

"${PYTHON}" -m pip install --upgrade pip
"${PYTHON}" -m pip install -r "${SCRIPT_DIR}/requirements.txt"

echo "venv ready at ${VENV_DIR}"
