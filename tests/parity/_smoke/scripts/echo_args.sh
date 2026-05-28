#!/usr/bin/env bash
# tests/parity/_smoke/scripts/echo_args.sh
# 引数を 1 行ずつ stdout に出力。stderr に "[args] count=N" を出す。
set -euo pipefail
echo "[args] count=$#" >&2
for a in "$@"; do
  printf '%s\n' "$a"
done
exit 0
