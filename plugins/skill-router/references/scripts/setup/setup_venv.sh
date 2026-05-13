#!/bin/bash
# venv 構築スクリプト（skill-router プラグイン共通、ADR-024 / scripts-policy.md 5.2 準拠）
# 使い方: bash setup_venv.sh <work_dir> [<requirements_path>] [<min_python_version>]
#   <work_dir> 配下に .venv を作成し、requirements.txt があればインストール
#   <min_python_version> 指定時、システム Python のバージョン要件を検証（例: 3.10）
#
# 役割分担:
#   - 本スクリプト: extension-reviewer / 手動テスト / CI 等が `<work_dir>/.venv` を
#     構築する用途のための **オーケストレータ向け汎用 venv 構築**。
#   - 内蔵 venv ライフサイクル管理 (`references/scripts/lib/venv_lifecycle.py`):
#     ランタイム（SessionStart / UserPromptSubmit フック）が `<base>/.venv` を
#     **動的に管理**（72h TTL / 1 セッション 3 回までの自動再構築 / fail-open）。
#     これは `~/.claude/rules/tools/python-venv.md` 5.1 で例外プラグインとして
#     列挙されている専用ライフサイクル管理であり、本スクリプトとは独立。
#
# セキュリティ: <min_python_version> はバリデーション後に環境変数経由で Python に渡す
# （bash 文字列補間によるコード注入を排除）
#
# 重要: PowerShell から呼び出さないこと。Bash 経由 (git-bash/MSYS2) で起動する前提。
#       PowerShell + chcp 65001 の組み合わせは Claude Code の stdout 解釈と衝突し
#       文字化け（UTF-8 → Latin-1 mojibake）を引き起こすため禁止。

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <work_dir> [<requirements_path>] [<min_python_version>]" >&2
  exit 1
fi

WORK_DIR="$1"
REQUIREMENTS_PATH="${2:-}"
MIN_PYTHON_VERSION="${3:-}"
VENV_DIR="${WORK_DIR}/.venv"

# 安全装置: WORK_DIR を正規化し、.claude/.local/ 配下であることを検証
# （誤指定で任意の場所に venv が作られる事故を防ぐ。teardown_venv.sh と同等のチェック）
if command -v realpath >/dev/null 2>&1; then
  RESOLVED_WORK_DIR=$(realpath -m "${WORK_DIR}")
elif command -v readlink >/dev/null 2>&1; then
  RESOLVED_WORK_DIR=$(readlink -f "${WORK_DIR}" 2>/dev/null || echo "${WORK_DIR}")
else
  RESOLVED_WORK_DIR="${WORK_DIR}"
fi
NORMALIZED_WORK_DIR="${RESOLVED_WORK_DIR//\\//}"
case "${NORMALIZED_WORK_DIR}" in
  *"/.claude/.local/"*)
    : # OK
    ;;
  *)
    echo "[setup_venv] Error: work_dir is not under .claude/.local/, refusing to create venv." >&2
    echo "  target (input): ${WORK_DIR}" >&2
    echo "  target (normalized): ${NORMALIZED_WORK_DIR}" >&2
    exit 1
    ;;
esac

# Python コマンド検出
# 注: pyenv-win 環境では python3 shim が `-m venv` 実行時に WinError 2 を出すため、
#     `python` を優先候補とし、`-m venv --help` の実体検証で動作可能性を確認する。
#     `--version` だけでは不十分（shim の応答だけで実体不在のケースがある）。
PYTHON_CMD=""
for candidate in python python3 py; do
  if "$candidate" -m venv --help >/dev/null 2>&1; then
    PYTHON_CMD="$candidate"
    break
  fi
done
if [ -z "${PYTHON_CMD}" ]; then
  echo "[setup_venv] Error: python / python3 / py のいずれでも venv モジュールが利用できません" >&2
  exit 1
fi
echo "[setup_venv] Python コマンド: ${PYTHON_CMD}"

# システム Python のバージョン要件チェック（指定時のみ、fail-closed）
if [ -n "${MIN_PYTHON_VERSION}" ]; then
  if ! [[ "${MIN_PYTHON_VERSION}" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "[setup_venv] Error: Invalid MIN_PYTHON_VERSION format: ${MIN_PYTHON_VERSION}" >&2
    exit 1
  fi
  ACTUAL_VERSION=$("${PYTHON_CMD}" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
  MEETS=$(MIN_PYTHON_VERSION="${MIN_PYTHON_VERSION}" "${PYTHON_CMD}" -c '
import os, sys
req = os.environ["MIN_PYTHON_VERSION"].split(".")
cur = (sys.version_info.major, sys.version_info.minor)
req_t = tuple(int(x) for x in req[:2]) if len(req) >= 2 else (int(req[0]), 0)
print("1" if cur >= req_t else "0")
' 2>/dev/null || echo "0")
  if [ "${MEETS}" != "1" ]; then
    echo "[setup_venv] Error: Python ${MIN_PYTHON_VERSION}+ required, found ${ACTUAL_VERSION}." >&2
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
echo "[setup_venv] Python: $("${PYTHON}" --version 2>&1)"
