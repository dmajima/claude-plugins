# Case 39: 全セル空テーブルの除外

## 入力

- 入力 PPTX: 1 スライドに 3×3 の **全セルが空** のテーブルを配置（レイアウト装飾としての空表）
- オプション: なし

## 期待動作

1. `_convert_table` が `table.rows` を走査
2. すべてのセルが空文字列（`.strip` 後）であることを検出
3. テーブルブロックを出力せず空文字列を返す
4. 該当スライドの他の本文 shape は通常通り出力
5. 終了コード: 0

## 期待出力

`output.md` にはテーブルブロックが含まれない。スライドの他のテキスト shape（タイトル等）は通常通り出力される。

## 分岐の根拠

`convert_from_pptx.py:_convert_table` 内の全セル空判定:
```python
if not any(any(cell.strip for cell in row) for row in cells_text):
    return ""  # all-cells-empty を装飾とみなして抑制
```

レイアウト装飾としての空表（プレゼン中で枠線のみ目的の表）を本文から除外するための分岐。

## 関連ケース

- [case-03_table_conversion.md](case-03_table_conversion.md): 通常テーブル変換
- [case-38_merged_cell_table.md](case-38_merged_cell_table.md): マージセル含むテーブル
