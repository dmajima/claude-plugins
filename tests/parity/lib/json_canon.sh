#!/usr/bin/env bash
# tests/parity/lib/json_canon.sh
# JSON を jq -S で canonical 化（キーソート + 整形）し、Bash 版と PowerShell 版で
# 出力 JSON のキー順が異なっても等価判定できるようにする。
#
# 使い方:
#   parity_json_canon < in > out

parity_json_canon() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[json_canon] jq required" >&2
    return 2
  fi
  jq -S .
}
