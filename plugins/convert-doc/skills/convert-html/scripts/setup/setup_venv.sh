#!/usr/bin/env bash
# setup_venv.sh - convert-html スキル用 venv 構築スクリプト
#
# 使い方:
#   bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" <WORK_DIR>
#
# 引数:
#   WORK_DIR  venv を作成するワークディレクトリのパス（通常はセッションの workspace/ 配下）
#             例: .claude/.local/work/20260408_01_convert_html/workspace
#
# 処理内容:
#   1. <WORK_DIR>/.venv に venv を作成
#   2. scripts/requirements.txt からパッケージをインストール

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください。例: setup_venv.sh .claude/.local/work/20260408_01_convert_html/workspace}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$WORK_DIR/.venv"
REQUIREMENTS="$SCRIPT_DIR/requirements.txt"

if [ ! -f "$REQUIREMENTS" ]; then
  echo "エラー: requirements.txt が見つかりません: $REQUIREMENTS" >&2
  exit 1
fi

if [ -d "$VENV_DIR" ] && [ -x "$VENV_DIR/Scripts/python" -o -x "$VENV_DIR/bin/python" ]; then
  echo "venv が既に存在します。再利用します: $VENV_DIR"
else
  echo "venv を作成しています: $VENV_DIR"
  python -m venv "$VENV_DIR"
fi

# Windows (Scripts/) / Unix (bin/) 両対応
if [ -f "$VENV_DIR/Scripts/pip" ]; then
  PIP="$VENV_DIR/Scripts/pip"
  PYTHON="$VENV_DIR/Scripts/python"
else
  PIP="$VENV_DIR/bin/pip"
  PYTHON="$VENV_DIR/bin/python"
fi

echo "パッケージをインストールしています: $REQUIREMENTS"
"$PIP" install --quiet -r "$REQUIREMENTS"

echo "完了: $VENV_DIR"
echo "Python: $PYTHON"
