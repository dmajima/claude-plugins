#!/usr/bin/env bash
# convert-pdf デモ実行スクリプト
#
# PDF 生成の主要経路（デフォルト / --css-template パススルー / エラー系）を確認する。
# 前提: venv 構築済み + `python -m playwright install chromium` 済み（初回 ~120MB）。
#
# 使い方:
#   bash demo.sh "<venv の python.exe パス>"
set -uo pipefail

PY="${1:?Usage: demo.sh <venv-python-path>}"
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONVERT="$PLUGIN_ROOT/references/scripts/convert-pdf/convert_pdf.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  if [[ "$3" -eq "$2" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}
is_pdf() {
  if head -c 5 "$2" 2>/dev/null | grep -q '%PDF-'; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1"; fail=$((fail+1)); fi
}

cat > "$WORK/sample.md" <<'EOF'
# デモ資料

## セクション1
本文。

| 列A | 列B |
|-----|-----|
| 1 | 2 |
EOF

echo "== 1) デフォルトデザインで PDF 生成 =="
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_default.pdf"; check "default PDF" 0 $?
is_pdf "PDF magic bytes (default)" "$WORK/out_default.pdf"

echo "== 2) --css-template パススルー（warm-paper があれば） =="
if [[ -f "$PLUGIN_ROOT/assets/css/warm-paper.css" ]]; then
  "$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_warm.pdf" \
    --css-template "$PLUGIN_ROOT/assets/css/warm-paper.css"
  check "css-template passthrough PDF" 0 $?
  is_pdf "PDF magic bytes (warm-paper)" "$WORK/out_warm.pdf"
fi

echo "== 3) エラー系 =="
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/x.pdf" --margin "10mm 20mm 30mm" 2>/dev/null
check "invalid --margin -> exit 1" 1 $?
"$PY" "$CONVERT" "$WORK/missing.md" "$WORK/x.pdf" 2>/dev/null
check "missing input -> exit 1" 1 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
