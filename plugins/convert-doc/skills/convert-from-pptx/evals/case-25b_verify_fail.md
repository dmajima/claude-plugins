# Case 25b: `verify_md.py` カバレッジ閾値未達 FAIL

## 入力

- 入力 PPTX: 元の PPTX（20 件のテキスト shape）
- 生成 MD: 10 件分のテキストのみ転記した Markdown（半分の本文が欠落）
- オプション: `--report <セッション>/coverage_report.json --threshold 0.85`

## 期待動作

1. `verify()` 内でカバレッジを計算
2. `text_coverage = 10/20 = 0.50` < `0.85` で `failures` に追加
3. `missing_texts` 配列に欠落した PPTX テキストを格納（slide_no / shape_id / text プレビュー）
4. `passed: false`
5. 標準出力に `RESULT: FAILED` と失敗理由を表示
6. 終了コード: 1

## 期待出力

```jsonc
{
  "summary": {
    "text_coverage": 0.5000,
    "text_total": 20,
    "text_present": 10,
    ...
  },
  "missing_texts": [
    {"slide_no": 2, "shape_id": 4, "text": "重要な本文の冒頭..."},
    {"slide_no": 2, "shape_id": 5, "text": "別の段落..."},
    ...
  ],
  "failures": ["text_coverage 50.00% < threshold 85%"],
  "passed": false
}
```

## 分岐の根拠

`verify_md.py:verify()`:
```python
if text_coverage < coverage_threshold:
    failures.append(f"text_coverage {text_coverage:.2%} < threshold {coverage_threshold:.0%}")
```

`main()` の `return 1` パス。

## 関連ケース

- [case-25a_verify_pass.md](case-25a_verify_pass.md): 閾値達成 PASS
- [case-25c_verify_suspicious.md](case-25c_verify_suspicious.md): 誤転記候補検出
