# Case 16: Content_Types.xml が PresentationML を示さない

## 入力

- 入力ファイル: `.pptx` 拡張子の ZIP だが、`[Content_Types].xml` に "presentationml" 文字列が含まれない（DOCX/XLSX を改名したファイル等）

## 期待動作

1. `_validate_pptx()` で拡張子・ZIP マジックは通過
2. `zf.read("[Content_Types].xml")` 取得成功
3. `"presentationml" not in content_types.lower()` が True → `ValueError`
4. メッセージ: `Input file is not a PresentationML document: <path>`
5. stderr 出力後 `sys.exit(1)`

## 期待出力

- 標準エラー: `Error: Input file is not a PresentationML document: fake.pptx`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx()`:
```python
if "presentationml" not in content_types.lower():
    raise ValueError(f"Input file is not a PresentationML document: {path}")
```

## 関連ケース

- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジックでの拒否
- [case-17_invalid_extension.md](case-17_invalid_extension.md): 拡張子での拒否
