#!/usr/bin/env bash
# plugins/extension-toolkit/tests/parity/run.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
PARITY_LIB_DIR="$REPO_ROOT/tests/parity/lib"
export PARITY_LIB_DIR
# shellcheck source=../../../../tests/parity/lib/driver.sh
source "$PARITY_LIB_DIR/driver.sh"
FILTER="${1:-}"
mapfile -t cases < <(LC_ALL=C find "$SCRIPT_DIR/cases" -type f -name "*.case" 2>/dev/null | LC_ALL=C sort)
[[ ${#cases[@]} -eq 0 ]] && { echo "[extension-toolkit parity] no cases found"; exit 0; }
for c in "${cases[@]}"; do
  base="$(basename "$c" .case)"
  [[ -n "$FILTER" && "$base" != *"$FILTER"* ]] && continue
  parity_run_case "$c" || true
done
