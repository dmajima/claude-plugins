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

## 関連ケース

- [case-09_input_not_found.md](case-09_input_not_found.md): ファイル不在
