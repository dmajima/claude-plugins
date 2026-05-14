# Case 29: `[Content_Types].xml` 欠落（KeyError パス）

## 入力

- 入力 PPTX: ZIP 内に `[Content_Types].xml` エントリが存在しない悪意 / 破損 PPTX
- 出力 MD: `output.md`

## 期待動作

1. `_validate_pptx()` で ZIP マジックは通過
2. ZIP bomb 検査も通過（総サイズ・圧縮率は正常）
3. `zf.read("[Content_Types].xml")` で `KeyError` が発生
4. `KeyError` を捕捉して `ValueError` に変換し raise
5. メッセージ: `Input file missing [Content_Types].xml: <path>`
6. python-pptx での読み込みは行われない（fail-closed）
7. 終了コード: 1

## 期待出力

- 標準エラー: `Error: Input file missing [Content_Types].xml: <path>`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx()`:
```python
try:
    with zipfile.ZipFile(path, "r") as zf:
        ...
        content_types = zf.read("[Content_Types].xml").decode("utf-8", errors="ignore")
except KeyError as exc:
    raise ValueError(f"Input file missing [Content_Types].xml: {path}") from exc
```

## 関連ケース

- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック不一致
- [case-16_invalid_content_types.md](case-16_invalid_content_types.md): Content_Types.xml は存在するが presentationml ではない
- [case-21a_zip_bomb_total_size.md](case-21a_zip_bomb_total_size.md): ZIP bomb 防御
