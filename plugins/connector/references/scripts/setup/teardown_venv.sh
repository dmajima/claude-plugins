#!/usr/bin/env bash
# teardown_venv.sh - connector プラグイン共通 venv 削除スクリプト（ADR-024）
#
# 使い方:
#   bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" <WORK_DIR>
#
# 引数:
#   WORK_DIR  venv が作成されているワークディレクトリのパス

set -euo pipefail

WORK_DIR="${1:?エラー: WORK_DIR を第1引数に指定してください}"
VENV_DIR="$WORK_DIR/.venv"

if [ -d "$VENV_DIR" ]; then
  rm -rf "$VENV_DIR"
  echo "削除しました: $VENV_DIR"
else
  echo "venv が存在しません（スキップ): $VENV_DIR"
fi
