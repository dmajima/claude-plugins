# Case 02: --landscape 指定（横向き出力）

## 入力

- 入力 MD: 任意
- オプション: `--landscape`

## 期待動作

1. argparse が `args.landscape = True` を設定
2. `page.pdf(landscape=True, ...)` で Playwright を呼び出し
3. PDF が横向きで出力される

## 期待出力

横向き A4 サイズの PDF（用紙幅 297mm、高さ 210mm）

## 分岐の根拠

`scripts/convert/convert_pdf.py:main()`:
```python
parser.add_argument("--landscape", action="store_true", help="Landscape orientation")
...
render_pdf(..., landscape=args.landscape, ...)
```

## 関連ケース

- [case-01_basic_a4.md](case-01_basic_a4.md): デフォルト（縦向き）
