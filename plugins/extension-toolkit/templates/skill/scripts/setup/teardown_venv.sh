#!/bin/bash
# venv 削除スクリプト（テンプレート）
# 使い方: bash teardown_venv.sh <work_dir>

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir>" >&2
  exit 1
fi

WORK_DIR="$1"
VENV_DIR="${WORK_DIR}/.venv"

if [ -d "${VENV_DIR}" ]; then
  rm -rf "${VENV_DIR}"
  echo "Removed venv at ${VENV_DIR}"
else
  echo "No venv at ${VENV_DIR}, nothing to do"
fi
