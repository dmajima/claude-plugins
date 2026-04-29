#!/bin/bash
# venv 撤去スクリプト（プラグイン横断）
# 使い方: bash teardown_venv.sh <work_dir>
#   <work_dir>/.venv を削除する

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir>" >&2
  exit 1
fi

WORK_DIR="$1"
VENV_DIR="${WORK_DIR}/.venv"

# 安全装置: .claude/.local/ 配下のみ削除を許可
case "${VENV_DIR}" in
  *"/.claude/.local/"*)
    : # OK
    ;;
  *)
    echo "[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete." >&2
    echo "  target: ${VENV_DIR}" >&2
    exit 1
    ;;
esac

if [ -d "${VENV_DIR}" ]; then
  rm -rf "${VENV_DIR}"
  echo "[teardown_venv] Removed ${VENV_DIR}"
else
  echo "[teardown_venv] No venv at ${VENV_DIR}, nothing to do"
fi
