# Case 42d: 画像総量・枚数の上限超過時の拒否（DoS 防御）

## 入力（2 パターン）

| パターン | PPTX 画像数 | 各画像サイズ | 期待結果 |
|---|---|---|---|
| 42d-A | 1001 枚 | 1 KB / 枚 | `MAX_IMAGE_COUNT_PER_PPTX = 1000` 超過 → `ValueError` |
| 42d-B | 100 枚 | 3 MiB / 枚（合計 300 MiB） | `MAX_TOTAL_IMAGE_BYTES = 256 MiB` 超過 → `ValueError` |

## 期待動作

1. `_validate_pptx` を通過
2. `_handle_picture` 内で書込前に上限チェック
3. 42d-A: 1001 枚目で `image count exceeds MAX_IMAGE_COUNT_PER_PPTX (1000)` を raise
4. 42d-B: `_image_total_bytes + len(blob) > MAX_TOTAL_IMAGE_BYTES` が True になった時点で `total image bytes would exceed MAX_TOTAL_IMAGE_BYTES (...)` を raise
5. いずれも終了コード 1

## 期待出力

- 42d-A: 標準エラー `Error: image count exceeds MAX_IMAGE_COUNT_PER_PPTX (1000)` / 終了コード 1
- 42d-B: 標準エラー `Error: total image bytes would exceed MAX_TOTAL_IMAGE_BYTES (268435456)` / 終了コード 1

## 分岐の根拠

`convert_from_pptx.py:_handle_picture`:
```python
if self._image_total_count >= MAX_IMAGE_COUNT_PER_PPTX:
    raise ValueError(
        f"image count exceeds MAX_IMAGE_COUNT_PER_PPTX ({MAX_IMAGE_COUNT_PER_PPTX})"
    )
if self._image_total_bytes + len(blob) > MAX_TOTAL_IMAGE_BYTES:
    raise ValueError(
        f"total image bytes would exceed MAX_TOTAL_IMAGE_BYTES ({MAX_TOTAL_IMAGE_BYTES})"
    )
```

CWE-400 / CWE-770 対策。ディスク満杯による外部サービス停止を防ぐ。

## 関連ケース

- [case-12_max_image_size_overflow.md](case-12_max_image_size_overflow.md): 1 画像あたりサイズ上限
- [case-22_image_extension_allowlist.md](case-22_image_extension_allowlist.md): 画像拡張子 allowlist
