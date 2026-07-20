#!/usr/bin/env bash
# Python スクリプトの安全実行ラッパー（deep-test 共通）
#
# 目的:
# - タイムアウト制御の共通化（ハング時に子プロセスを確実に停止する）
# - UTF-8 エンコーディング環境変数の強制（文字化け防止）
# - PowerShell ツール強制運用（フォールバックモード）環境で .md の起動例から
#   直接 `& python.exe script.py` を打たせないための単一入口
#
# 補足: deep-test の Python スクリプト（results_manager.py / generate_excel.py /
# generate_markdown.py）は標準ライブラリ + PyYAML + openpyxl のみを使用する純 Python
# であり、python-pptx 系の子プロセスハング既知事象の対象ライブラリを含まない
# （Bash 経由の直接実行で問題ないことは実測済み）。本ラッパーはタイムアウトと
# エンコーディングを共通化する防御層として提供する。
#
# usage:
#   run_via_job.sh <venv-python> <script.py> [args...]
# env:
#   RUN_VIA_JOB_TIMEOUT : タイムアウト秒（既定 300）
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "usage: run_via_job.sh <venv-python> <script.py> [args...]" >&2
    exit 64
fi

TIMEOUT_SEC="${RUN_VIA_JOB_TIMEOUT:-300}"
PYTHON_EXE="$1"; shift
SCRIPT_PATH="$1"; shift

if [ ! -x "$PYTHON_EXE" ]; then
    echo "[run_via_job] python executable not found or not executable: $PYTHON_EXE" >&2
    echo "[run_via_job] venv を setup_venv.sh で構築し、venv の python を指定してください。" >&2
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
