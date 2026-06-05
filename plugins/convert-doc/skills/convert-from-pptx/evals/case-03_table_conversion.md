# Case 03: 表 shape → Markdown パイプ表

## 入力

- 入力 PPTX: 1 スライドに 2 行 × 3 列の表を含む
  - ヘッダ行: 項目 / 説明 / 値
  - データ行 1: A / 説明A / 100
  - データ行 2: B / 説明B|超過 / 200

## 期待動作

1. `shape.has_table == True` で `_convert_table` を呼び出し
2. 1 行目をヘッダとして抽出
3. パイプ表を組み立て（セル内の `|` は `\|` にエスケープ）
4. 列数は header_cells で決定

## 期待出力

```markdown
| 項目 | 説明 | 値 |
| --- | --- | --- |
| A | 説明A | 100 |
| B | 説明B\|超過 | 200 |
```

## 分岐の根拠

`convert_from_pptx.py:_convert_table`:
```python
lines = [
    "| " + " | ".join(_escape_md_pipe(c) for c in header_cells) + " |",
    "| " + " | ".join(["---"] * col_count) + " |",
]
```

`_escape_md_pipe`:
```python
def _escape_md_pipe(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", "<br>")
```

## 関連ケース

なし
