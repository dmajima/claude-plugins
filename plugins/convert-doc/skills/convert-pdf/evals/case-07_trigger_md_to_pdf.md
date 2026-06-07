# case-07 Markdown を PDF に変換

ユーザーが Markdown ファイルを PDF に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この Markdown を PDF に変換して" |
| モード | 対話 |

## 期待

- convert-pdf スキルが起動する
- 入力 MD ファイルのパスを確認する
- convert-html 経由で中間 HTML を生成する
- Playwright Chromium で A4 縦・背景色印刷ありの PDF を生成する
