# Case 25a: `verify_md.py` カバレッジ検証 PASS

## 入力

- 入力 PPTX: 元の PPTX（3 スライド、テキスト + 画像 + テーブル含む）
- 生成 MD: PPTX のテキスト・テーブル・画像参照を忠実に転記した Markdown
- オプション: `--report <セッション>/coverage_report.json --threshold 0.85`

## 期待動作

1. `_extract_pptx_inventory` で PPTX 内のテキスト・テーブル・画像・コネクタを抽出
2. `_extract_md_features` で MD の正規化テキスト・画像・Mermaid ブロックを抽出
3. テキストカバレッジ・テーブルセルカバレッジを計算
4. `text_coverage >= 0.85` かつ `table_cell_coverage >= 0.85` を満たす
5. 画像数も PPTX 画像数の 50% 以上
6. コネクタ 5 件以上ある場合は Mermaid エッジ数 >= 1
7. `failures` 配列が空 → `passed: true`
8. 終了コード: 0

## 期待出力

```jsonc
{
  "summary": {
    "text_coverage": 0.9500,
    "text_total": 20,
    "text_present": 19,
    "table_cell_coverage": 1.0,
    "pptx_image_total": 3,
    "md_image_total": 3,
    "pptx_connector_total": 0,
    "mermaid_edge_total": 0,
    "suspicious_md_phrase_count": 0
  },
  "missing_texts": [],
  "missing_table_cells": [],
  "suspicious_md_phrases": [],
  "failures": [],
  "passed": true
}
```

標準出力に `RESULT: PASSED` を表示。

## 分岐の根拠

`verify_md.py:verify` の判定ロジック:
```python
failures = []
if text_coverage < coverage_threshold:
    failures.append(...)
if table_coverage < coverage_threshold:
    failures.append(...)
report["passed"] = not failures
```

## 起動経路についての注記（verify_md.py のラッパー）

`verify_md.py` 自体は `python-pptx` を内部で使うため、`convert_from_pptx.py` と
同じ「Windows + PowerShell + `Start-Process -NoNewWindow` でハング」事象が
発生しうる。専用ラッパー `run_verify_via_job.sh` を経由して起動する:

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/convert-from-pptx/run_verify_via_job.sh" \
  "<入力PPTXパス>" \
  "<検証対象MDパス>" \
  -PythonExe "$SESSION_DIR/workspace/.venv/Scripts/python.exe" \
  --report "<セッション>/coverage_report.json" \
  --threshold 0.85
```
直接 `& "$py.exe" verify_md.py ...` で起動するとハングする可能性があるため必ず
ラッパー経由とする。設計と挙動は `run_via_job.sh` と対称。

## 関連ケース

- [case-25b_verify_fail.md](case-25b_verify_fail.md): 閾値未達 FAIL
- [case-25c_verify_suspicious.md](case-25c_verify_suspicious.md): 誤転記候補検出
- [case-47_fail_close_stderr_flush.md](case-47_fail_close_stderr_flush.md): convert_from_pptx.py 側の同等保護
