# Case 46: 章扉スライドでの装飾的章番号除外

## 入力

- 入力 PPTX: 1 スライドが **章扉レイアウト**（`is_section_cover_layout = true`）で、以下 3 つの shape を含む:
  - shape A: 純数字 1〜3 桁テキスト「3」（章番号装飾、`top_ratio=0.05`、`font_size=72pt`）
  - shape B: 章タイトル「設計フェーズ」（`top_ratio=0.4`、`font_size=44pt`）
  - shape C: 補足テキスト「2026 年 Q2 開始」（`top_ratio=0.7`、`font_size=18pt`）
- オプション: なし

## 期待動作

1. `_is_section_cover_layout(slide)` で章扉判定 → True
2. `_compute_slide_visual_stats()` 内の装飾判定で shape A について以下を確認:
   - `is_section_cover_layout = True`（章扉）
   - `_is_decoration_number(shape)` で True（純数字 1〜3 桁テキスト）
3. shape A の shape_id を `_current_decoration_shape_ids` に登録
4. `_collect_shape()` 内で当該 shape_id が登録済みのためスキップ
5. shape B（章タイトル）と shape C（補足）は通常通り出力
6. 終了コード: 0

## 期待出力

`output.md`:
```markdown
## 設計フェーズ

2026 年 Q2 開始
```

shape A「3」は装飾扱いで本文に含まれない。

## 分岐の根拠

`convert_from_pptx.py` の装飾除外:
```python
# _compute_slide_visual_stats() 内
if self._current_is_section_cover and self._is_decoration_number(shape):
    self._current_decoration_shape_ids.add(shape_id)
```

`_is_decoration_number()`:
```python
def _is_decoration_number(self, shape) -> bool:
    """章扉スライドの純数字 1〜3 桁テキストを装飾として判定."""
    text = (shape.text_frame.text or "").strip()
    return text.isdigit() and len(text) <= 3
```

章扉スライドでは、視覚的な装飾として大きく配置される章番号（1, 2, 3 等）が本文として誤って Markdown に出力されないようフィルタする境界ケース。

## 関連ケース

- [case-30_title_estimation_fallback.md](case-30_title_estimation_fallback.md): 章扉でのタイトル推定 B 経路
- [case-37_title_estimation_boundary.md](case-37_title_estimation_boundary.md): タイトル推定 EMU 境界
- [case-33_decoration_reasons_boundary.md](case-33_decoration_reasons_boundary.md): 通常装飾判定境界
