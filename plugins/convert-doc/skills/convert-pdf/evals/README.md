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

## 実行確認方法

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-pdf/convert_pdf.py" <ケースの入力> <出力> [オプション]
```
