#!/usr/bin/env bash
# add-design-html デモ実行スクリプト
#
# 検証スクリプトの PASS / FAIL 判定（正規デザイン・契約違反デザイン・HTML ペア）を
# 通しで確認する。venv 不要（検証スクリプトは標準ライブラリのみ）。
#
# 使い方:
#   bash demo.sh "<python パス（venv でなくても可）>"
set -uo pipefail

PY="${1:?Usage: demo.sh <python-path>}"
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
VCSS="$PLUGIN_ROOT/references/scripts/add-design-html/validate_css.py"
VHTML="$PLUGIN_ROOT/references/scripts/add-design-html/validate_html.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  if [[ "$3" -eq "$2" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}

echo "== 1) 正規デザインは PASS =="
"$PY" "$VCSS" "$PLUGIN_ROOT/assets/css/template.css" > /dev/null; check "template.css -> PASS" 0 $?
if [[ -f "$PLUGIN_ROOT/assets/css/warm-paper.css" ]]; then
  "$PY" "$VCSS" "$PLUGIN_ROOT/assets/css/warm-paper.css" > /dev/null; check "warm-paper.css -> PASS" 0 $?
fi
"$PY" "$VHTML" "$PLUGIN_ROOT/assets/html/template.html" > /dev/null; check "template.html -> PASS" 0 $?

echo "== 2) 契約違反デザインは FAIL =="
cat > "$WORK/fake.css" <<'EOF'
#wrapper { color: red; }
#lb-overlay { display: flex; }
@media (max-width: 768px) { body { font-size: 90%; } }
EOF
"$PY" "$VCSS" "$WORK/fake.css" > /dev/null; check "contract-breaking css -> FAIL" 1 $?

cat > "$WORK/fake.html" <<'EOF'
<html><head><title>{{TITLE}}</title><style>{{CSS}}{{PYGMENTS_CSS}}</style></head>
<body><div id="wrap">{{TOC_SIDEBAR}}<div id="main-content">
<span class="doc-title-badge">x</span><div class="article-body">{{BODY_HTML}}</div>
</div></div>{{JS_BLOCK}}</body></html>
EOF
"$PY" "$VHTML" "$WORK/fake.html" > /dev/null; check "broken class token html -> FAIL" 1 $?

echo "== 3) usage エラー（非 UTF-8 / 引数なし） =="
"$PY" "$VCSS" 2>/dev/null; check "no args -> exit 2" 2 $?
printf '\xff\xfe\x00broken' > "$WORK/binary.css"
"$PY" "$VCSS" "$WORK/binary.css" 2>/dev/null; check "non-UTF8 -> exit 2" 2 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
