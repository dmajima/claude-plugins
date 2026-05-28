#!/usr/bin/env bash
# tests/parity/_smoke/run.sh
# parity test 基盤自体の動作確認用スモークランナー。
# プラグイン実装を待たずに driver.sh / lib/ の正常動作を検証する。
#
# 使い方:
#   bash tests/parity/_smoke/run.sh                  # 全スモークケース
#   bash tests/parity/_smoke/run.sh <case_id_prefix> # 指定ケースのみ
#
# 注意:
#   このランナーは plugins/*/tests/parity/run.sh のパターンに合致しないため、
#   tests/parity/run_all.sh からは自動実行されない（意図的）。
#   開発時・基盤改修時にのみ実行する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARITY_LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
export PARITY_LIB_DIR
# shellcheck source=../lib/driver.sh
source "$PARITY_LIB_DIR/driver.sh"

FILTER="${1:-}"

declare -a cases
mapfile -t cases < <(LC_ALL=C find "$SCRIPT_DIR/cases" -type f -name "*.case" | LC_ALL=C sort)

pass=0
fail=0
skip=0

for c in "${cases[@]}"; do
  base="$(basename "$c" .case)"
  if [[ -n "$FILTER" && "$base" != *"$FILTER"* ]]; then
    continue
  fi
  out="$(parity_run_case "$c" || true)"
  echo "$out"
  while IFS= read -r line; do
    case "$line" in
      "PASS "*) pass=$((pass + 1)) ;;
      "FAIL "*) fail=$((fail + 1)) ;;
      "SKIP "*) skip=$((skip + 1)) ;;
    esac
  done <<<"$out"
done

echo ""
echo "--- smoke summary ---"
echo "PASS=$pass  FAIL=$fail  SKIP=$skip"
if [[ $fail -gt 0 ]]; then
  exit 1
fi
exit 0
