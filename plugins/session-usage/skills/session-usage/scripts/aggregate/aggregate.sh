#!/usr/bin/env bash
# aggregate.sh - Claude Code セッション JSONL からトークン消費量を集計 (Bash + Python 版)
#
# 通常運用は本スクリプトを利用する。本体は aggregate.py (Bash から Python 起動)。
#
# 引数:
#   --session-id <id>     : 対象セッション ID
#   --project-key <key>   : プロジェクトキー
#   --as-object           : JSON 出力
#   --stdout              : 整形済み文字列を stdout に出力 (Bash 経由はデフォルト ON)
#   --copy                : クリップボードコピー

set -euo pipefail

# Python の UTF-8 設定（python-encoding-mandatory.md 準拠）
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
py="$script_dir/aggregate.py"

if [[ ! -f "$py" ]]; then
  echo "[aggregate] Python 本体が見つかりません: $py" >&2
  exit 2
fi

python_bin=""
if command -v python >/dev/null 2>&1; then
  python_bin="$(command -v python)"
elif command -v python3 >/dev/null 2>&1; then
  python_bin="$(command -v python3)"
elif command -v py >/dev/null 2>&1; then
  python_bin="$(command -v py)"
else
  echo "[aggregate] python / python3 / py のいずれも PATH に見つかりません。" >&2
  exit 127
fi

exec "$python_bin" -u "$py" "$@"
