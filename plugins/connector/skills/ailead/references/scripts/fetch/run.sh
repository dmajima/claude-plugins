#!/usr/bin/env bash
# run.sh - fetch_share.py を実行するラッパー
#
# 使い方:
#   bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/run.sh" \
#     --python "<venv>/Scripts/python" \
#     --url "<ailead共有URL>" \
#     --output "<出力ディレクトリ>"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH_SCRIPT="$SCRIPT_DIR/fetch_share.py"

PYTHON_EXE=""
URL=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --python)  PYTHON_EXE="$2"; shift 2 ;;
    --url)     URL="$2"; shift 2 ;;
    --output)  OUTPUT="$2"; shift 2 ;;
    *)         echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$PYTHON_EXE" ] || [ -z "$URL" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: run.sh --python <path> --url <url> --output <dir>" >&2
  exit 1
fi

if [ ! -f "$PYTHON_EXE" ]; then
  echo "Error: Python executable not found: $PYTHON_EXE" >&2
  exit 1
fi

"$PYTHON_EXE" "$FETCH_SCRIPT" --url "$URL" --output "$OUTPUT"
