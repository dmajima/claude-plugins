#!/usr/bin/env bash
# Python スクリプトの安全実行ラッパー（skill-router 共通・任意利用）
#
# 目的:
# - タイムアウト制御の共通化（ハング時に子プロセスを確実に停止する）
# - UTF-8 エンコーディング環境変数の強制（文字化け防止）
# - 手動実行時に `& python.exe script.py` 形式を打たせないための単一入口
#
# 補足: フック（build_index_on_start.sh / route_prompt.sh）は Bash 経由で
# Python を起動しており、python-pptx 系で報告されている PowerShell 経由の
# 子プロセスハング事象の対象ではない。本ラッパーは、利用者が PowerShell 等から
# 手動でスクリプト（clean_old_sessions.py / venv_lifecycle.py 等）を実行する
# 場合に、タイムアウトとエンコーディングを共通化する防御層として提供する。
# フック経路はこのラッパーを経由しない（プロセス起動を増やさないため）。
#
# usage:
#   run_via_job.sh <python> <script.py> [args...]
# env:
#   RUN_VIA_JOB_TIMEOUT : タイムアウト秒（既定 300）
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: run_via_job.sh <python> <script.py> [args...]" >&2
    exit 64
fi

TIMEOUT_SEC="${RUN_VIA_JOB_TIMEOUT:-300}"
PYTHON_EXE="$1"; shift
SCRIPT_PATH="$1"; shift

if [ ! -x "$PYTHON_EXE" ] && ! command -v "$PYTHON_EXE" >/dev/null 2>&1; then
    echo "[run_via_job] python executable not found: $PYTHON_EXE" >&2
    exit 66
fi

if [ ! -f "$SCRIPT_PATH" ]; then
    echo "[run_via_job] script not found: $SCRIPT_PATH" >&2
    exit 66
fi

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

# timeout: 期限超過時は TERM、猶予 10 秒後に KILL
exec timeout --signal=TERM --kill-after=10 "$TIMEOUT_SEC" \
    "$PYTHON_EXE" -u "$SCRIPT_PATH" "$@"
