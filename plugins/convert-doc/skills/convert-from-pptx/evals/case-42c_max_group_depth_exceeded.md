# Case 42c: `MAX_GROUP_DEPTH` 上限超過時の拒否（DoS 防御）

## 入力

- 入力 PPTX: 1 スライドにグループ shape を 21 段ネスト（`MAX_GROUP_DEPTH = 20` を 1 超過）
  - Group A (depth=1) → Group B (depth=2) → ... → Group U (depth=21)
- 出力 MD: `<セッション>/output.md`

## 期待動作

1. `_validate_pptx` を通過
2. `_walk_shape_to_dict` がグループの再帰で `depth + 1` を渡す
3. depth = 21 に到達した時点で関数冒頭の `depth > MAX_GROUP_DEPTH` 判定が True
4. `ValueError` を raise
5. メッセージ: `Group nesting exceeds MAX_GROUP_DEPTH (20) on slide N`
6. 終了コード: 1

## 期待出力

- 標準エラー: `Error: Group nesting exceeds MAX_GROUP_DEPTH (20) on slide 1`
- 終了コード: 1
- スタックオーバーフローは発生しない（早期停止）

## 分岐の根拠

`convert_from_pptx.py:_walk_shape_to_dict`:
```python
def _walk_shape_to_dict(self, ..., depth: int = 0) -> None:
    if depth > MAX_GROUP_DEPTH:
        raise ValueError(
            f"Group nesting exceeds MAX_GROUP_DEPTH ({MAX_GROUP_DEPTH}) on slide {slide_no}"
        )
    for shape in shape_iter:
        ...
        if shape.shape_type == MSO_SHAPE_TYPE.GROUP:
            self._walk_shape_to_dict(shape.shapes, ..., depth=depth + 1)
```

CWE-674（Uncontrolled Recursion）対策。深いグループネストによるスタック枯渇を防ぐ。

## 関連ケース

- [case-42a_max_slides_exceeded.md](case-42a_max_slides_exceeded.md): スライド数上限
- [case-42b_max_shapes_exceeded.md](case-42b_max_shapes_exceeded.md): shape 数上限
