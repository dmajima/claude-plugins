# Case 04: 入力 MD ファイルが存在しない

## 入力

- 入力 MD: 存在しないパス（例: `./missing.md`）

## 期待動作

1. `Path(args.input).exists()` が False
2. stderr に `Error: Input file not found: <path>` を出力
3. `sys.exit(1)` で終了

## 期待出力

- 標準エラー: `Error: Input file not found: <path>`
- 終了コード: 1
- 出力 PDF: 生成されない
- Chromium 起動なし（早期 exit）

## 分岐の根拠

`references/scripts/convert-pdf/convert_pdf.py:main()`:
```python
input_path = Path(args.input)
if not input_path.exists():
    print(f"Error: Input file not found: {input_path}", file=sys.stderr)
    sys.exit(1)
```

## 関連ケース

なし（エラー系）
