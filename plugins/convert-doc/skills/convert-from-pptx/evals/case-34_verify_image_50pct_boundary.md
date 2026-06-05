# Case 34: `verify_md.py` 画像カバレッジ 50% 境界値

## 入力（3 パターン）

| パターン | PPTX 画像数 | MD 画像数 | 期待判定 |
|---|---|---|---|
| 34a | 4 | 2 | PASS（ちょうど 50%、`md_image_total < pptx_image_total * 0.5` が False）|
| 34b | 4 | 1 | FAIL（25% < 50%、`failures` に追加）|
| 34c | 4 | 3 | PASS（75%）|

- オプション: `--report <セッション>/coverage_report.json --threshold 0.85`

## 期待動作

1. `verify` で `pptx_image_total = 4`、`md_image_total` をそれぞれカウント
2. 判定式 `pptx_image_total and md_image_total < pptx_image_total * 0.5` を評価
3. 34a: `2 < 4 * 0.5 = 2.0` は False → PASS
4. 34b: `1 < 2.0` は True → FAIL（`images: pptx=4 md=1 (less than 50%)` を `failures` に追加）
5. 34c: `3 < 2.0` は False → PASS

## 期待出力

- 34a / 34c: `passed: true`、終了コード 0
- 34b: `passed: false`、終了コード 1、`failures` に `"images: pptx=4 md=1 (less than 50%)"` を含む

## 分岐の根拠

`verify_md.py:verify`:
```python
if pptx_image_total and md_image_total < pptx_image_total * 0.5:
    failures.append(f"images: pptx={pptx_image_total} md={md_image_total} (less than 50%)")
```

50% ちょうどは PASS（`<` 比較のため）。閾値変更時の回帰検出用境界ケース。

## 関連ケース

- [case-25a_verify_pass.md](case-25a_verify_pass.md): 通常 PASS
- [case-25b_verify_fail.md](case-25b_verify_fail.md): テキストカバレッジ FAIL
- [case-04_image_extraction.md](case-04_image_extraction.md): 画像抽出の正常系
