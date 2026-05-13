#!/usr/bin/env bash
# teardown_venv.sh - convert-doc プラグイン共通 venv 削除スクリプト（ADR-024 準拠）
#
# 使い方:
#   bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" <WORK_DIR>

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "エラー: WORK_DIR を第1引数に指定してください。例: teardown_venv.sh .claude/.local/work/(session)/workspace" >&2
  exit 1
fi
WORK_DIR="$1"
VENV_DIR="$WORK_DIR/.venv"

if [ -d "$VENV_DIR" ]; then
  rm -rf "$VENV_DIR"
  echo "削除しました: $VENV_DIR"
else
  echo "スキップ（存在しない）: $VENV_DIR"
fi
