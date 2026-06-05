# Case 03: --no-background 指定（背景色なし）

## 入力

- 入力 MD: 任意（背景色を持つ要素 — コードブロック・表ヘッダー等を含むと違いが見やすい）
- オプション: `--no-background`

## 期待動作

1. argparse が `args.no_background = True` を設定
2. `render_pdf(..., print_background=not args.no_background)` → `print_background=False`
3. Playwright が背景色を印刷せず、白地に黒文字主体の PDF を出力

## 期待出力

- A4 縦・背景色なし PDF
- コードブロック・表のヘッダーも背景色なしでレンダリング
- モノクロ印刷向けに最適化

## 分岐の根拠

`references/scripts/convert-pdf/convert_pdf.py:main`:
```python
parser.add_argument("--no-background", action="store_true", ...)
...
render_pdf(..., print_background=not args.no_background)
```

## 関連ケース

- [case-01_basic_a4.md](case-01_basic_a4.md): デフォルト（背景印刷あり）
