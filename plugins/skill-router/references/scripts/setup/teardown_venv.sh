#!/bin/bash
# venv 撤去スクリプト（skill-router プラグイン共通、ADR-024 準拠）
# 使い方: bash teardown_venv.sh <work_dir>
#   <work_dir>/.venv を削除する
#
# 役割分担:
#   - 本スクリプト: extension-reviewer / 手動テスト / CI 等が `<work_dir>/.venv` を
#     撤去する用途のための **オーケストレータ向け汎用 venv 撤去**。
#   - 内蔵 venv ライフサイクル管理 (`references/scripts/lib/venv_lifecycle.py`):
#     ランタイムフックが `<base>/.venv` の TTL（72h）切れ時に自動撤去する。
#     こちらは本スクリプトとは独立に動作する。

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir>" >&2
  exit 1
fi

WORK_DIR="$1"
VENV_DIR="${WORK_DIR}/.venv"

# 安全装置 1: パスを正規化してシンボリックリンク迂回を防ぐ（fail-closed）
if command -v realpath >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(realpath -m "${VENV_DIR}")
elif command -v readlink >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(readlink -f "${VENV_DIR}" 2>/dev/null || true)
  if [ -z "${RESOLVED_VENV_DIR}" ]; then
    echo "[teardown_venv] Error: readlink -f failed to resolve path, refusing to delete." >&2
    echo "  target (input): ${VENV_DIR}" >&2
    exit 1
  fi
else
  echo "[teardown_venv] Error: neither realpath nor readlink available, refusing to delete (fail-closed)." >&2
  exit 1
fi

NORMALIZED_PATH="${RESOLVED_VENV_DIR//\\//}"

# 安全装置 2: .claude/.local/ 配下のみ削除を許可（正規化後パスで判定）
case "${NORMALIZED_PATH}" in
  *"/.claude/.local/"*)
    : # OK
    ;;
  *)
    echo "[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete." >&2
    echo "  target (input): ${VENV_DIR}" >&2
    echo "  target (resolved): ${RESOLVED_VENV_DIR}" >&2
    echo "  target (normalized): ${NORMALIZED_PATH}" >&2
    exit 1
    ;;
esac

# 安全装置 3: ルート / ホームディレクトリ等のシステムパスを禁止
case "${NORMALIZED_PATH}" in
  "/" | "/root"* | "/home"* | "/etc"* | "/usr"* | "/var"* | "/bin"* | "/sbin"* | "/opt"* | "/Users"* | [A-Za-z]:[\\/]*)
    case "${NORMALIZED_PATH}" in
      *"/.claude/.local/"*)
        : # .claude/.local/ を含むため許容
        ;;
      *)
        echo "[teardown_venv] Error: refusing to operate on system path: ${NORMALIZED_PATH}" >&2
        exit 1
        ;;
    esac
    ;;
esac

if [ -d "${VENV_DIR}" ]; then
  rm -rf "${VENV_DIR}"
  echo "[teardown_venv] Removed ${VENV_DIR}"
else
  echo "[teardown_venv] No venv at ${VENV_DIR}, nothing to do"
fi
