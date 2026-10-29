# Case 42a: `MAX_SLIDES` 上限超過時の拒否（DoS 防御）

## 入力

- 入力 PPTX: スライド数 1001（`MAX_SLIDES = 1000` を 1 超過）
- 出力 MD: `<セッション>/output.md`

## 期待動作

1. `_validate_pptx` で ZIP マジック・拡張子・ZIP bomb 検査を通過
2. `_load_presentation` 内で `len(list(presentation.slides))` を計測
3. `slide_count > MAX_SLIDES` で `ValueError` を raise
4. メッセージ: `slide count 1001 exceeds MAX_SLIDES (1000)`
5. python-pptx での詳細処理は行われない（早期停止・fail-closed）
6. 終了コード: 1

## 期待出力

- 標準エラー: `Error: slide count 1001 exceeds MAX_SLIDES (1000)`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_load_presentation`:
```python
slide_count = len(list(self._presentation_cache.slides))
if slide_count > MAX_SLIDES:
    raise ValueError(
        f"slide count {slide_count} exceeds MAX_SLIDES ({MAX_SLIDES})"
    )
```

CWE-400 / CWE-770 対策のための上限定数。閾値変更時の回帰検出にも使う境界ケース。

## 関連ケース

- [case-42b_max_shapes_exceeded.md](case-42b_max_shapes_exceeded.md): スライドあたり shape 数上限
- [case-42c_max_group_depth_exceeded.md](case-42c_max_group_depth_exceeded.md): グループネスト深度上限
- [case-42d_max_image_count_exceeded.md](case-42d_max_image_count_exceeded.md): 画像枚数上限
- [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md): ZIP bomb 防御
