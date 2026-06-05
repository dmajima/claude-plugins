# Case 21b: ZIP bomb 防御（圧縮率異常）

## 入力

- 入力 PPTX: いずれかのエントリで `file_size / compress_size > MAX_COMPRESSION_RATIO` (200) を満たす悪意 ZIP（極端な高圧縮率で展開時にメモリ枯渇を狙う）

## 期待動作

1. `_validate_pptx` で `zf.infolist` を走査
2. `info.compress_size > 0` で `ratio = info.file_size / info.compress_size` を算出
3. `ratio > MAX_COMPRESSION_RATIO` が True になった時点で `ValueError` を raise
4. メッセージ: `Suspicious compression ratio (<ratio>x) for entry '<filename>' in <path>`
5. python-pptx での読み込みは行われない（fail-closed）

## 期待出力

- 標準エラー: `Error: Suspicious compression ratio (350.0x) for entry 'ppt/slides/slide1.xml' in <path>`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx`:
```python
if info.compress_size > 0:
    ratio = info.file_size / info.compress_size
    if ratio > MAX_COMPRESSION_RATIO:
        raise ValueError(
            f"Suspicious compression ratio ({ratio:.1f}x) "
            f"for entry '{info.filename}' in {path}"
        )
```

## 関連ケース

- [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md): 総展開サイズ超過での拒否
- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック検証
