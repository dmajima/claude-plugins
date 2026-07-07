# convert-pdf evals

`convert-pdf` スキルの動作分岐ごとの期待挙動ケース集。

## ケース一覧

| ファイル | 対象分岐 |
|---------|---------|
| [case-01_basic_a4.md](case-01_basic_a4.md) | 標準変換（A4 縦・背景印刷あり） |
| [case-02_landscape.md](case-02_landscape.md) | `--landscape` 指定 |
| [case-03_no_background.md](case-03_no_background.md) | `--no-background` 指定 |
| [case-04_input_not_found.md](case-04_input_not_found.md) | 入力 MD が存在しない |
| [case-05_playwright_not_installed.md](case-05_playwright_not_installed.md) | Playwright/Chromium 未インストール |
| [case-06_convert_html_resolution_order.md](case-06_convert_html_resolution_order.md) | convert-html スクリプトの解決順序 |
| [case-07_trigger_md_to_pdf.md](case-07_trigger_md_to_pdf.md) | トリガー: Markdown→PDF 変換の基本依頼（対話モード） |
| [case-08_trigger_design_doc_pdf.md](case-08_trigger_design_doc_pdf.md) | トリガー: 設計書 PDF 化の自然言語依頼（対話モード） |
| [case-09_trigger_report_pdf_output.md](case-09_trigger_report_pdf_output.md) | トリガー: 資料 PDF 出力の自然言語依頼（対話モード） |
| [case-10_noninteractive_landscape.md](case-10_noninteractive_landscape.md) | 横向き指定による非対話モード（`--landscape` 適用） |

## 実行確認方法

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pdf/convert_pdf.py" <ケースの入力> <出力> [オプション]
```

## デモ実行スクリプト

[`demo.sh`](demo.sh) は PDF 生成の主要経路（デフォルト / `--css-template` パススルー / エラー系）を
Chromium 実機で確認する再現スクリプト（要 `playwright install chromium`）。
実行方法はスクリプト冒頭のコメントを参照。
