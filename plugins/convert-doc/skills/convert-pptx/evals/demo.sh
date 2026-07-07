#!/usr/bin/env bash
# convert-pptx デモ実行スクリプト
#
# 主要経路（デフォルト変換 / テーマ適用 / --dump-default-theme / エラー系）を
# 通しで確認する。venv は setup_venv.sh で事前構築しておくこと。
#
# 使い方:
#   bash demo.sh "<venv の python.exe パス>"
#   例: bash demo.sh ".claude/.local/work/<session>/workspace/.venv/Scripts/python.exe"
set -uo pipefail

PY="${1:?Usage: demo.sh <venv-python-path>}"
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONVERT="$PLUGIN_ROOT/references/scripts/convert-pptx/convert_pptx.py"
THEME_DIR="$PLUGIN_ROOT/assets/pptx-themes"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() { # <label> <expected-exit> <actual-exit>
  if [[ "$3" -eq "$2" ]]; then echo "[PASS] $1"; pass=$((pass+1));
  else echo "[FAIL] $1 (expected exit $2, got $3)"; fail=$((fail+1)); fi
}

cat > "$WORK/sample.md" <<'EOF'
# デモ資料
概要文

## セクション1
本文と **強調**。

| 列A | 列B |
|-----|-----|
| 1 | 2 |

```python
print("hello")  # comment
```
EOF

echo "== 1) デフォルト変換 =="
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_default.pptx"; check "default conversion" 0 $?

echo "== 2) --dump-default-theme とテーマ適用 =="
"$PY" "$CONVERT" --dump-default-theme > "$WORK/default-theme.json"; check "dump-default-theme" 0 $?
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_roundtrip.pptx" --theme "$WORK/default-theme.json"
check "theme roundtrip conversion" 0 $?

if [[ -f "$THEME_DIR/dark-console.json" ]]; then
  "$PY" "$CONVERT" "$WORK/sample.md" "$WORK/out_dark.pptx" --theme "$THEME_DIR/dark-console.json"
  check "bundled dark-console theme" 0 $?
fi

echo "== 3) エラー系 =="
printf '{"colors": {"primaryy": "#112233"}}' > "$WORK/bad.json"
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/x.pptx" --theme "$WORK/bad.json" 2>/dev/null
check "unknown theme key -> exit 1" 1 $?
"$PY" "$CONVERT" "$WORK/sample.md" "$WORK/x.pptx" --primary-color "not-a-color" 2>/dev/null
check "invalid --primary-color -> exit 2" 2 $?
"$PY" "$CONVERT" "$WORK/missing.md" "$WORK/x.pptx" 2>/dev/null
check "missing input file -> exit 1" 1 $?

echo
echo "RESULT: $pass passed, $fail failed"
exit $((fail > 0))
