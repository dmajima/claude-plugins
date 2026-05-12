# Case 21: ZIP bomb 防御（高圧縮率・総展開サイズ上限）

## 入力

- 入力 PPTX: 以下のいずれかを満たす悪意 ZIP
  - パターン A: いずれかのエントリで `file_size / compress_size > 200`
  - パターン B: 全エントリの `file_size` 合計が 256 MiB を超過

## 期待動作

### パターン A（圧縮率異常）

1. `_validate_pptx()` で `zf.infolist()` を走査
2. `ratio = info.file_size / info.compress_size > MAX_COMPRESSION_RATIO (=200)` が True
3. `ValueError`: `Suspicious compression ratio (<ratio>x) for entry '<filename>' in <path>`

### パターン B（総展開サイズ超過）

1. `total_uncompressed` を累積
2. `total_uncompressed > MAX_TOTAL_UNCOMPRESSED_BYTES (=256 MiB)` が True
3. `ValueError`: `Input PPTX exceeds uncompressed size limit (<N> > <max>): <path>`

## 期待出力

- 標準エラー: 上記いずれかのメッセージ
- 終了コード: 1
- python-pptx での読み込みは行われない（ZIP bomb による DoS を未然に防止）

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx()`:
```python
for info in zf.infolist():
    total_uncompressed += info.file_size
    if total_uncompressed > MAX_TOTAL_UNCOMPRESSED_BYTES:
        raise ValueError(f"Input PPTX exceeds uncompressed size limit ...")
    if info.compress_size > 0:
        ratio = info.file_size / info.compress_size
        if ratio > MAX_COMPRESSION_RATIO:
            raise ValueError(f"Suspicious compression ratio ({ratio:.1f}x) ...")
```

## 関連ケース

- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック検証
