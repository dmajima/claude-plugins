# Case 06: 入力 MD ファイルが存在しない

## 入力

- 入力 MD: 存在しないパス（例: `./missing.md`）

## 期待動作

1. `Path(args.input).exists()` が False
2. stderr に `Error: Input file not found: <path>` を出力
3. `sys.exit(1)` で終了

## 期待出力

- 標準エラー: `Error: Input file not found: <path>`
- 終了コード: 1
- 出力 PPTX: 生成されない

## 分岐の根拠

`references/scripts/convert-pptx/convert_pptx.py:main`:
```python
if not input_path.exists():
    print(f"Error: Input file not found: {input_path}", file=sys.stderr)
    sys.exit(1)
```

## 関連ケース

なし（エラー系）
