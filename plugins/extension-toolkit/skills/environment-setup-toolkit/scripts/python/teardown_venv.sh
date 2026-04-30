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

# 安全装置 1: パスを正規化してシンボリックリンク迂回を防ぐ
# realpath が使えない環境（古い Bash 等）では絶対パスへの変換のみ実施
if command -v realpath >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(realpath -m "${VENV_DIR}")
elif command -v readlink >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(readlink -f "${VENV_DIR}" 2>/dev/null || echo "${VENV_DIR}")
else
  RESOLVED_VENV_DIR="${VENV_DIR}"
  echo "[teardown_venv] Warning: realpath/readlink unavailable, using literal path." >&2
fi

# Windows ネイティブのバックスラッシュパスをスラッシュに正規化（クロスプラットフォーム対応）
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

# 安全装置 3: ルート / ホームディレクトリ等のシステムパスを禁止（正規化後パスで判定）
case "${NORMALIZED_PATH}" in
  "/" | "/root"* | "/home"* | "/etc"* | "/usr"* | "/var"* | "/bin"* | "/sbin"* | "/opt"* | "/Users"* | [A-Za-z]:[\\/]*)
    # これらは .claude/.local/ 配下に該当しないため通常は到達しないが、二重チェック
    case "${NORMALIZED_PATH}" in
      *"/.claude/.local/"*)
        : # 例外的に許容
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
