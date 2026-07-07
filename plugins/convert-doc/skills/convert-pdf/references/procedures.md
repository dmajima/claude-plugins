# convert-pdf 実行手順

環境構築（venv・依存パッケージ・Chromium）は `setup.md` を参照すること。
デザイン（CSS）の選択ルールは convert-html と共通の
[`../../convert-html/references/css-js-selection.md`](../../convert-html/references/css-js-selection.md) を参照すること。

## 変換スクリプト実行

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pdf/convert_pdf.py" \
  "<入力MDファイルパス>" \
  "<出力PDFファイルパス>" \
  [--title "タイトル文字列"] \
  [--format A4] \
  [--landscape] \
  [--margin 20mm] \
  [--no-background] \
  [--css-template "<デザインCSSの絶対パス>"] \
  [--html-template "<HTMLテンプレートの絶対パス>"]
```

- 出力先が未指定の場合、入力ファイルと同ディレクトリ・同名で `.pdf` 拡張子
- `--format` は Chromium がサポートする用紙名（`A4`, `A3`, `Letter`, `Legal` など）
- `--margin` は `20mm` のような単一値（全辺同じ）、または `"20mm 15mm 25mm 15mm"` 形式（上右下左）
- `--no-background` を指定すると背景色を印刷しない（モノクロ印刷向け）
- `--css-template` / `--html-template` は convert-html の `convert.py` にそのまま渡される（省略時はデフォルトデザイン）。
  対話モードで追加デザインを検出した場合は css-js-selection.md の選択結果をここに渡す

## 出力先の決定ルール

| ユーザー指定 | 出力先 |
|---|---|
| 出力パスを明示指定 | 指定パス |
| 出力パスなし | 入力 MD ファイルと同ディレクトリに `<stem>.pdf` |
| ワークディレクトリへの出力を希望 | `.claude/.local/work/yyyyMMdd_nn_convert_pdf/<stem>.pdf` |

## convert_pdf.py の変換処理フロー

スクリプト内部で以下の順に処理する。

1. **入力検証** — 入力 MD ファイルの存在確認
2. **HTML 生成** — 同一プラグイン内の `convert-html` の `convert.py` を subprocess で呼び出し、一時 HTML を `workspace/tmp/` に生成
3. **Chromium 起動** — Playwright の `sync_playwright` で Chromium を起動
4. **HTML 読み込み** — `file://<一時HTMLパス>` を `goto` で開き、ネットワーク idle まで待機
5. **PDF 出力** — `page.pdf(...)` で指定パスに保存
6. **クリーンアップ** — Chromium を閉じる

## アセットの場所

| ファイル | パス |
|---|---|
| 変換スクリプト | `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pdf/convert_pdf.py` |
| 兄弟スキル（HTML 生成） | `${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py` |

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `Executable doesn't exist` エラー | `playwright install chromium` を venv 内で実行 |
| mermaid 図がレンダリングされない | 一時 HTML が空白部分になっていないか確認。`convert-html` の出力が先に成功している必要がある |
| フォントが反映されない | Playwright の `page.wait_for_load_state("networkidle")` を待ってから PDF 生成することで Web フォント読み込みを保証 |
| 横スクロールする幅広の表 | `--landscape` オプションで横向きに切り替え、または CSS で `table-layout: fixed` を使用 |
