# Case 38: マージセル（colspan / rowspan）を含むテーブル

## 入力

- 入力 PPTX: 1 スライドに 3×3 テーブルを配置
  - 1 行目: 「ヘッダ A」「ヘッダ B」「ヘッダ C」
  - 2 行目: 「データ X」（colspan=2）「データ Y」
  - 3 行目: 「データ P」「データ Q」「データ R」
- オプション: なし

## 期待動作

1. `_convert_table` が `table.rows` を線形に走査
2. python-pptx のマージセル挙動により、colspan=2 のセルは 2 つの異なる cell オブジェクトとして同一テキストを返す
3. GFM パイプ表として出力（列数を保つ）
4. マージ表現は GFM に存在しないため、同一テキストが両セルに展開される
5. 終了コード: 0

## 期待出力

```markdown
| ヘッダ A | ヘッダ B | ヘッダ C |
| --- | --- | --- |
| データ X | データ X | データ Y |
| データ P | データ Q | データ R |
```

または `_convert_table` 側でマージセルを検知して「（マージ）」マーカーを付与する設計を採用する場合は、別パターンを許容。

## 分岐の根拠

`convert_from_pptx.py:_convert_table` のロジック:
```python
for row in shape.table.rows:
    cells_text = [_cell_text(cell) for cell in row.cells]
    ...
```

python-pptx の `row.cells` はマージセルでも個別 cell オブジェクトを返すため、現実装は **マージを GFM に展開する** 仕様。pipe 表の列数整合性が保たれる利点と引き換えに、視覚的なマージ情報は失われる。

このケースはマージセルが「データ損失なし・列数整合性あり」で変換されることを担保するための境界ケース。

## 関連ケース

- [case-03_table_conversion.md](case-03_table_conversion.md): 通常テーブル変換
- [case-39_empty_table_skip.md](case-39_empty_table_skip.md): 全セル空テーブルの除外
