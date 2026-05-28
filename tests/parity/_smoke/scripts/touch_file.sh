#!/usr/bin/env bash
# tests/parity/_smoke/scripts/touch_file.sh
# 環境変数 OUT_FILE で指定されたパスに固定内容のファイルを作成する。
set -euo pipefail
target="${OUT_FILE:-}"
if [[ -z "$target" ]]; then
  echo "OUT_FILE not set" >&2
  exit 2
fi
dir="$(dirname -- "$target")"
mkdir -p -- "$dir"
printf 'line1\nline2\n' > "$target"
echo "touched: $target"
exit 0
