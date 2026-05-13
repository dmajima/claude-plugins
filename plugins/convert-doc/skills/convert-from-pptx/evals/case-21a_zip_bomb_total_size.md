# Case 21a: ZIP bomb 防御（総展開サイズ超過）

## 入力

- 入力 PPTX: 全エントリの `file_size` 合計が `MAX_TOTAL_UNCOMPRESSED_BYTES` (256 MiB) を超過する悪意 ZIP

## 期待動作

1. `_validate_pptx()` で `zf.infolist()` を走査
2. `total_uncompressed += info.file_size` の累積値が 256 MiB を超過した時点で `ValueError` を raise
3. メッセージ: `Input PPTX exceeds uncompressed size limit (<N> > <max>): <path>`
4. python-pptx での読み込みは行われない（fail-closed）

## 期待出力

- 標準エラー: `Error: Input PPTX exceeds uncompressed size limit (...) > 268435456: <path>`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx()`:
```python
for info in zf.infolist():
    total_uncompressed += info.file_size
    if total_uncompressed > MAX_TOTAL_UNCOMPRESSED_BYTES:
        raise ValueError(
            f"Input PPTX exceeds uncompressed size limit "
            f"({total_uncompressed} > {MAX_TOTAL_UNCOMPRESSED_BYTES}): {path}"
        )
```

## 関連ケース

- [case-21b_zip_bomb_compression_ratio.md](case-21b_zip_bomb_compression_ratio.md): 圧縮率異常での拒否
- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック検証
