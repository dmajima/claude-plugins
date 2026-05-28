# Case 11: ZIP マジック不一致（非 PPTX 入力）

## 入力

- 入力ファイル: `fake.pptx`（拡張子は pptx だが中身はテキスト）

## 期待動作

1. `_validate_pptx()` でファイル先頭 4 バイトを読み取り
2. `PK\x03\x04` と一致しない → `ValueError`
3. メッセージ: `Input file is not a valid PPTX (zip magic): <path>`
4. stderr に出力して `sys.exit(1)`

## 期待出力

- 標準エラー: `Error: Input file is not a valid PPTX (zip magic): fake.pptx`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx()`:
```python
with open(path, "rb") as fh:
    magic = fh.read(4)
if magic != PPTX_MAGIC:
    raise ValueError(f"Input file is not a valid PPTX (zip magic): {path}")
```

## 起動経路についての注記

`run_via_job.sh` ラッパー経由起動が必須（[`../references/procedures.md`](../references/procedures.md) 参照）。
ラッパー経由の場合の挙動は [case-09_input_not_found.md](case-09_input_not_found.md) の「起動経路についての注記」を参照。
ラッパーは `ValueError` 経路で投げられたエラーメッセージも `2>&1` 経由で呼び出し元に確実に伝える。

## 関連ケース

- [case-09_input_not_found.md](case-09_input_not_found.md): ファイル不在
- [case-47_fail_close_stderr_flush.md](case-47_fail_close_stderr_flush.md): fail-close 経路の stderr flush 保証
