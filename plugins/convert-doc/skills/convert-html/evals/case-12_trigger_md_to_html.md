# case-12 Markdown を HTML に変換

ユーザーが Markdown ファイルを HTML に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この Markdown を HTML に変換して" |
| モード | 対話 |

## 期待

- convert-html スキルが起動する
- 入力 MD ファイルのパスを確認する
- CSS が複数存在する場合は選択 UI を表示する
- 自己完結型 HTML（画像 base64 埋込・mermaid SVG インライン）を生成する
