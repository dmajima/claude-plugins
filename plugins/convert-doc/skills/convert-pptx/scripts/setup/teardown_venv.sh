#!/usr/bin/env bash
# teardown_venv.sh - convert-pptx スキル用 venv 削除スクリプト
#
# 使い方:
#   bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" <WORK_DIR>

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください。例: teardown_venv.sh .claude/.local/work/20260421_01_convert_pptx/workspace}"
VENV_DIR="$WORK_DIR/.venv"

if [ -d "$VENV_DIR" ]; then
  rm -rf "$VENV_DIR"
  echo "削除しました: $VENV_DIR"
else
  echo "スキップ（存在しない）: $VENV_DIR"
fi
