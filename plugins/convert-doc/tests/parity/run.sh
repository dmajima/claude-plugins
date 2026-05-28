#!/usr/bin/env bash
# plugins/convert-doc/tests/parity/run.sh
# convert-doc プラグインの parity test ランナー。
# Bash 版と PowerShell 版の動作等価性をケース単位で検証する。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PARITY_LIB_DIR="$REPO_ROOT/tests/parity/lib"
export PARITY_LIB_DIR

# shellcheck source=../../../../tests/parity/lib/driver.sh
source "$PARITY_LIB_DIR/driver.sh"

FILTER="${1:-}"

mapfile -t cases < <(LC_ALL=C find "$SCRIPT_DIR/cases" -type f -name "*.case" 2>/dev/null | LC_ALL=C sort)

if [[ ${#cases[@]} -eq 0 ]]; then
  echo "[convert-doc parity] no cases found"
  exit 0
fi

for c in "${cases[@]}"; do
  base="$(basename "$c" .case)"
  if [[ -n "$FILTER" && "$base" != *"$FILTER"* ]]; then
    continue
  fi
  parity_run_case "$c" || true
done
