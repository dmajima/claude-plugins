#!/usr/bin/env bash
# tests/parity/run_all.sh
# 全プラグインの parity test を順次起動し、集計レポートを出力する。
#
# 使い方:
#   bash tests/parity/run_all.sh                    # 全件
#   bash tests/parity/run_all.sh <plugin_name>      # 1 プラグインのみ
#   bash tests/parity/run_all.sh --self-check       # 各実装を 2 回連続実行して揺らぎ検出

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

MODE="all"
ONLY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-check) MODE="self-check"; shift ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--self-check] [<plugin_name>]

  <plugin_name>   plugins/<plugin_name>/tests/parity/run.sh のみ実行
  --self-check    PS↔PS / Bash↔Bash の連続実行で揺らぎを検出
EOF
      exit 0
      ;;
    *) ONLY="$1"; shift ;;
  esac
done

# プラグイン別ランナーの一覧
mapfile -t runners < <(find "$REPO_ROOT/plugins" -mindepth 4 -maxdepth 4 -path "*/tests/parity/run.sh" 2>/dev/null | LC_ALL=C sort)

if [[ ${#runners[@]} -eq 0 ]]; then
  echo "[run_all] no plugin parity runners found (plugins/*/tests/parity/run.sh)" >&2
  echo "[run_all] OK - 0 plugins, 0 cases (nothing to verify yet)"
  exit 0
fi

total_pass=0
total_fail=0
total_skip=0
declare -a failed_ids=()

for runner in "${runners[@]}"; do
  # runner は plugins/<plugin>/tests/parity/run.sh
  plugin_dir="$(dirname -- "$(dirname -- "$(dirname -- "$runner")")")"
  plugin_name="$(basename -- "$plugin_dir")"

  if [[ -n "$ONLY" && "$plugin_name" != "$ONLY" ]]; then
    continue
  fi

  echo "=== plugin: $plugin_name ==="
  out_file="$(mktemp)"
  if [[ "$MODE" == "self-check" ]]; then
    PARITY_MODE=self-check bash "$runner" | tee "$out_file"
  else
    bash "$runner" | tee "$out_file"
  fi

  while IFS= read -r line; do
    case "$line" in
      "PASS "*) total_pass=$((total_pass + 1)) ;;
      "FAIL "*) total_fail=$((total_fail + 1)); failed_ids+=("$plugin_name:${line#FAIL }") ;;
      "SKIP "*) total_skip=$((total_skip + 1)) ;;
    esac
  done <"$out_file"
  rm -f "$out_file"
done

echo ""
echo "===== parity summary ====="
echo "PASS: $total_pass"
echo "FAIL: $total_fail"
echo "SKIP: $total_skip"
if [[ $total_fail -gt 0 ]]; then
  echo ""
  echo "Failed cases:"
  printf '  - %s\n' "${failed_ids[@]}"
  exit 1
fi
exit 0
