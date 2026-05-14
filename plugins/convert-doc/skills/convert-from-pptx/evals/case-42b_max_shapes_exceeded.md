# Case 42b: `MAX_SHAPES_PER_SLIDE` 上限超過時の拒否（DoS 防御）

## 入力

- 入力 PPTX: 1 スライドに shape 5001 個を配置（`MAX_SHAPES_PER_SLIDE = 5000` を 1 超過）
- 出力 MD: `<セッション>/output.md`

## 期待動作

1. `_validate_pptx()` を通過
2. `_walk_shape_to_dict()` または `_collect_shape()` の走査ループ内で shape 5001 個目に到達した時点で `ValueError` を raise
3. メッセージ: `shape count exceeds MAX_SHAPES_PER_SLIDE (5000) on slide N`
4. 早期停止により残りの shape は処理されない（fail-closed）
5. 終了コード: 1

## 期待出力

- 標準エラー: `Error: shape count exceeds MAX_SHAPES_PER_SLIDE (5000) on slide 1`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_walk_shape_to_dict()`:
```python
for shape in shape_iter:
    if len(shapes_out) >= MAX_SHAPES_PER_SLIDE:
        raise ValueError(
            f"shape count exceeds MAX_SHAPES_PER_SLIDE ({MAX_SHAPES_PER_SLIDE}) on slide {slide_no}"
        )
```

CWE-400 対策。多数 shape による OOM / CPU 枯渇を防ぐ。

## 関連ケース

- [case-42a_max_slides_exceeded.md](case-42a_max_slides_exceeded.md): スライド数上限
- [case-42c_max_group_depth_exceeded.md](case-42c_max_group_depth_exceeded.md): グループ再帰深度上限
- [case-33_decoration_reasons_boundary.md](case-33_decoration_reasons_boundary.md): 装飾判定境界値
