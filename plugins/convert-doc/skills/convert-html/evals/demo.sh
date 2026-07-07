#!/usr/bin/env bash
# convert-html デモ実行スクリプト
#
# 主要経路（デフォルト解決 / --css-template 明示 / JS 選択分岐）を通しで確認する。
# venv は setup_venv.sh で事前構築しておくこと。
#
# 使い方:
#   bash demo.sh "<venv の python.exe パス>"
set -uo pipefail

PY="${1:?Usage: demo.sh <venv-python-path>}"
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONVERT="$PLUGIN_ROOT/references/scripts/convert-html/convert.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() {
  if [[ "$3" -eq "$2" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}
contains() { # <label> <file> <needle> (1=expect present, 0=expect absent) <flag>
  if grep -qF -- "$3" "$2"; then found=1; else found=0; fi
  if [[ "$found" -eq "$4" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1"; fail=$((fail+1)); fi
}

cat > "$WORK/sample.md" <<'EOF'
# デモ資料

## セクション1
本文と ~~取り消し~~。

- [x] タスク完了

```bash
# コード内コメント（タイトルに拾われないこと）
echo "~~not strikethrough~~"
```
EOF

echo "== 1) デフォルト解決（テンプレート引数なし） =="
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_default.html"; check "default resolution" 0 $?
contains "title is real H1 (not code comment)" "$WORK/out_default.html" "<title>デモ資料</title>" 1
contains "code content untouched" "$WORK/out_default.html" "~~not strikethrough~~" 1

echo "== 2) --css-template 明示（warm-paper があれば） =="
if [[ -f "$PLUGIN_ROOT/assets/css/warm-paper.css" ]]; then
  "$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_warm.html" \
    --css-template "$PLUGIN_ROOT/assets/css/warm-paper.css"
  check "explicit css-template" 0 $?
fi

echo "== 3) JS 選択分岐 =="
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_nojs.html" --js-features ""
check "no-JS conversion" 0 $?
contains "no script tag when JS disabled" "$WORK/out_nojs.html" "<script>" 0
contains "no TOC element when toc-toggle excluded" "$WORK/out_nojs.html" '<aside id="toc-sidebar"' 0

echo "== 4) エラー系 =="
"$PY" "$CONVERT" "$WORK/missing.md" "$WORK/x.html" 2>/dev/null
check "missing input -> exit 1" 1 $?
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/x.html" --css-template "$WORK/nope.css" 2>/dev/null
check "missing css-template -> exit 1" 1 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
