# Case 40: 水平方向の連続テキスト行結合（`_merge_horizontal_text_rows`）

## 入力（3 パターン）

| パターン | shape 配置 | 期待結果 |
|---|---|---|
| 40a | shape A (top=100, left=200) + shape B (top=200, left=600) | 同一行（top 差 100 < 250_000）→ 結合 |
| 40b | shape A (top=100, left=200) + shape B (top=249_999+100, left=600) | 同一行（top 差ぎりぎり境界以下）→ 結合 |
| 40c | shape A (top=100, left=200) + shape B (top=250_001+100, left=600) | 別行（top 差超過）→ 結合しない |

- オプション: なし

## 期待動作

1. `_merge_horizontal_text_rows()` が同一スライドの text shape リストを走査
2. 連続する shape の top 差が `TOP_TOLERANCE = 250_000 EMU` 以内なら同一行とみなし、全角スペース `　` 区切りで結合
3. 40a / 40b は 1 行のテキストとして出力、40c は 2 つの段落として出力
4. 終了コード: 0

## 期待出力

- 40a / 40b: `shape Aのテキスト　shape Bのテキスト`（全角スペース区切りで 1 行）
- 40c: `shape Aのテキスト\n\nshape Bのテキスト`（2 段落）

## 分岐の根拠

`convert_from_pptx.py:_merge_horizontal_text_rows()`:
- `TOP_TOLERANCE = 250_000 EMU`（標準スライド高 6,858,000 EMU で約 3.6%）
- 連続 shape が `abs(curr.top - prev.top) <= TOP_TOLERANCE` を満たす場合に同一行扱い
- 結合区切りは全角スペース `　`（日本語スライド前提）

閾値境界（249,999 vs 250,001 EMU）は明示的に固定しておくことで、定数変更時の回帰を検出できる。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): 単一テキスト shape の通常変換
- [case-13_monospace_code_block.md](case-13_monospace_code_block.md): 段落単位での区別
