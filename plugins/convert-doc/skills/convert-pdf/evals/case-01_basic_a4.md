# Case 01: 標準変換（A4 縦・背景印刷あり）

## 入力

- 入力 MD: 任意の標準的な Markdown
- オプション: なし（すべてデフォルト）

## 期待動作

1. `locate_convert_html_script()` で convert-html を解決
2. tempdir に中間 HTML を生成（subprocess で convert-html を呼び出し、`shell=False`）
3. Playwright Chromium で `page.goto(file://, wait_until="networkidle")`
4. `page.pdf(format="A4", landscape=False, margin={top:20mm,...}, print_background=True)`
5. PDF を `output_pdf` に保存
6. tempdir 自動削除

## 期待出力

- A4 縦サイズ・全周 20mm マージン・背景色印刷ありの PDF
- HTML 版と同一デザイン（mermaid・コードブロック・表は HTML から焼き込み）

## 分岐の根拠

`scripts/convert/convert_pdf.py:main()` のデフォルト値:
- `--format`: `"A4"`
- `--landscape`: action `store_true`（未指定 → False）
- `--margin`: `"20mm"`
- `--no-background`: action `store_true`（未指定 → `print_background=True`）

## 関連ケース

- [case-02_landscape.md](case-02_landscape.md): 横向き
- [case-03_no_background.md](case-03_no_background.md): 背景なし
