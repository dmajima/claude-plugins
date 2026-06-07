# case-51 PPTX を Markdown に変換

ユーザーが PPTX ファイルを Markdown に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この PPTX を Markdown に変換して" |
| モード | 対話 |

## 期待

- convert-from-pptx スキルが起動する
- 入力 PPTX のパスをユーザーに確認する（未指定の場合）
- Phase 1 で Python による構造化 JSON 抽出を実行する
- Phase 2 で Claude が JSON を解釈して Markdown を生成する
