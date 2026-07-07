#!/usr/bin/env bash
# add-design-pptx デモ実行スクリプト
#
# テーマ検証（PASS / FAIL / usage エラー）と、dump-default-theme を種にした
# テーマ作成 → サンプル変換の流れを通しで確認する。
# venv は setup_venv.sh で事前構築しておくこと（python-pptx が必要）。
#
# 使い方:
#   bash demo.sh "<venv の python.exe パス>"
set -uo pipefail

PY="${1:?Usage: demo.sh <venv-python-path>}"
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VTHEME="$PLUGIN_ROOT/references/scripts/add-design-pptx/validate_theme.py"
CONVERT="$PLUGIN_ROOT/references/scripts/convert-pptx/convert_pptx.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  if [[ "$3" -eq "$2" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}

echo "== 1) 同梱テーマの検証 PASS =="
if [[ -f "$PLUGIN_ROOT/assets/pptx-themes/dark-console.json" ]]; then
  "$PY" "$VTHEME" "$PLUGIN_ROOT/assets/pptx-themes/dark-console.json" > /dev/null
  check "dark-console.json -> PASS" 0 $?
fi

echo "== 2) dump-default-theme を種に新テーマ作成 → 検証 → サンプル変換 =="
"$PY" "$CONVERT" --dump-default-theme > "$WORK/seed.json"; check "dump-default-theme" 0 $?
"$PY" - "$WORK/seed.json" "$WORK/demo-green.json" <<'PYEOF'
import json, sys
sys.stdout.reconfigure(encoding="utf-8")
seed = json.load(open(sys.argv[1], encoding="utf-8"))
seed["name"] = "demo-green"
seed["colors"]["primary"] = "#1B5E20"
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(seed, f, ensure_ascii=False, indent=2)
print("theme written")
PYEOF
"$PY" "$VTHEME" "$WORK/demo-green.json" > /dev/null; check "new theme -> PASS" 0 $?

printf '# T\n\n## S\nbody\n' > "$WORK/sample.md"
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/sample-green.pptx" --theme "$WORK/demo-green.json"
check "sample conversion with new theme" 0 $?

echo "== 3) 不正テーマは FAIL / usage エラー =="
printf '{"colors": {"primaryy": "#112233"}}' > "$WORK/bad.json"
"$PY" "$VTHEME" "$WORK/bad.json" > /dev/null; check "unknown key -> FAIL(1)" 1 $?
"$PY" "$VTHEME" "$WORK/missing.json" 2>/dev/null; check "missing file -> exit 2" 2 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
