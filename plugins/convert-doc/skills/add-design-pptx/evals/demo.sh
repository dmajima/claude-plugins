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

echo "== 4) composition（構図）: 同期照合 / 検証 / 変換 / round-trip =="
CHECK_COMP="$PLUGIN_ROOT/references/scripts/add-design-pptx/check_default_composition.py"
"$PY" "$CHECK_COMP" > /dev/null; check "check_default_composition (doc<->code sync)" 0 $?

"$PY" - "$WORK/demo-comp.json" <<'PYEOF'
import json, sys
sys.stdout.reconfigure(encoding="utf-8")
theme = {
    "name": "demo-comp",
    "composition": {
        "cover": {
            "shapes": [{"x": 0, "y": 7.0, "w": "full", "h": 0.3, "color": "accent"}],
            "title": {"x": 1.0, "y": 2.4, "w": "sym", "h": 1.8, "color": "primary"},
            "subtitle": {"x": 1.0, "y": 4.4, "w": "sym", "h": 1.2, "color": "text"},
        },
        "content_header": {
            "shapes": [{"x": 0.5, "y": 1.0, "w": "sym", "h": 0.02, "color": "hr"}],
            "title": {"x": 0.5, "y": 0.2, "w": "sym", "h": 0.7, "color": "primary", "anchor": "middle"},
            "content_top": 1.2,
        },
    },
}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(theme, f, ensure_ascii=False, indent=2)
print("composition theme written")
PYEOF
"$PY" "$VTHEME" "$WORK/demo-comp.json" > /dev/null; check "composition theme -> PASS" 0 $?
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/sample-comp.pptx" --theme "$WORK/demo-comp.json"
check "sample conversion with composition theme" 0 $?

"$PY" - "$CONVERT" "$WORK/demo-comp.json" "$WORK/demo-comp-rt.json" <<'PYEOF'
import sys
from pathlib import Path
sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, str(Path(sys.argv[1]).resolve().parent))
from convert_pptx import load_theme, theme_to_json
theme1 = load_theme(Path(sys.argv[2]))
Path(sys.argv[3]).write_text(theme_to_json(theme1), encoding="utf-8")
theme2 = load_theme(Path(sys.argv[3]))
assert theme2.composition == theme1.composition, "round-trip mismatch"
print("round-trip OK")
PYEOF
check "composition round-trip (load -> dump -> load)" 0 $?

echo "== 5) composition のエラー / 警告系 =="
printf '{"composition": {}}' > "$WORK/bad-comp.json"
"$PY" "$VTHEME" "$WORK/bad-comp.json" > /dev/null; check "empty composition -> FAIL(1)" 1 $?

"$PY" - "$WORK/demo-comp.json" "$WORK/demo-comp-warn.json" <<'PYEOF'
import json, sys
sys.stdout.reconfigure(encoding="utf-8")
with open(sys.argv[1], encoding="utf-8") as f:
    theme = json.load(f)
theme["name"] = "demo-comp-warn"
theme["layout_in"] = {"title_band_height": 1.2}
with open(sys.argv[2], "w", encoding="utf-8") as f:
    json.dump(theme, f, ensure_ascii=False)
print("warn theme written")
PYEOF
"$PY" "$VTHEME" "$WORK/demo-comp-warn.json" > /dev/null 2> "$WORK/warn.txt"
grep -q "title_band_height is not used" "$WORK/warn.txt"
check "content_header + title_band_height coexistence warning" 0 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
