# Case 17: 入力拡張子が .pptx / .pptm 以外

## 入力

- 入力ファイル: `report.docx`（存在はするが拡張子が PPTX/PPTM ではない）

## 期待動作

1. `_validate_pptx` でファイル存在は通過
2. `path.suffix.lower not in (".pptx", ".pptm")` が True → `ValueError`
3. メッセージ: `Input file is not PPTX/PPTM (extension): <path>`
4. stderr 出力後 `sys.exit(1)`

## 期待出力

- 標準エラー: `Error: Input file is not PPTX/PPTM (extension): report.docx`
- 終了コード: 1

## 分岐の根拠

`convert_from_pptx.py:_validate_pptx`:
```python
if path.suffix.lower not in (".pptx", ".pptm"):
    raise ValueError(f"Input file is not PPTX/PPTM (extension): {path}")
```

## 補足

`.pptm`（マクロ有効プレゼンテーション）は正常受理される。

## 関連ケース

- [case-11_invalid_pptx_magic.md](case-11_invalid_pptx_magic.md): ZIP マジック検証
- [case-16_invalid_content_types.md](case-16_invalid_content_types.md): Content_Types 検証
