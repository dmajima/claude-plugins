# Case 33: 装飾判定 `decoration_reasons >= 2` の境界値

## 入力

- 入力 PPTX: 1 スライドに以下 3 つの text shape を配置
  - shape A: 通常本文（条件 0 → 装飾候補ではない）
  - shape B: 「グレー色（is_grayish_color=true）」**のみ** 1 条件該当（装飾候補だが reasons=1）
  - shape C: 「グレー色 + 極小フォント」 2 条件該当（装飾候補で reasons=2、装飾扱い）
- オプション: なし

## 期待動作

1. `_compute_slide_visual_stats` で各 shape の装飾理由を集計
2. shape A は装飾扱いされず本文として出力
3. shape B は `decoration_reasons = 1` のため装飾扱いされず本文として出力（境界値以下）
4. shape C は `decoration_reasons >= 2` のため装飾として除外
5. 終了コード: 0

## 期待出力

`output.md` には shape A と shape B のテキストが含まれ、shape C のテキストは含まれない。

## 分岐の根拠

`convert_from_pptx.py:_compute_slide_visual_stats` の装飾判定:
- 各 shape に対し以下の条件で reasons カウントを増やす:
  - `is_grayish_color`
  - `font_size_max_pt < median * 0.7`
  - 右下隅 (`top_ratio > 0.75 && left_ratio > 0.55`) + 短文
  - その他
- `reasons >= 2` を満たす shape を `_current_decoration_shape_ids` に登録
- `_collect_shape` 内で当該 shape を除外

この境界（reasons=1 と reasons=2）は誤除外バグの温床のため evals で固定する。

## 関連ケース

- [case-01_normal_with_title.md](case-01_normal_with_title.md): 通常本文の出力
- [case-13_monospace_code_block.md](case-13_monospace_code_block.md): フォント特性ベースの分類
