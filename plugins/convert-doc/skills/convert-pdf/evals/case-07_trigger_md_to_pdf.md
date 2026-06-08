# case-07 Markdown を PDF に変換

ユーザーが Markdown ファイルを PDF に変換するよう依頼した場合の基本トリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この Markdown を PDF に変換して" |
| モード | 対話 |

## 期待動作

- convert-pdf スキルが起動する
- 入力 MD ファイルのパスを確認する
- convert-html 経由で中間 HTML を生成する
- Playwright Chromium で A4 縦・背景色印刷ありの PDF を生成する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | A4 縦・背景色印刷ありの PDF ファイル（セッションフォルダ直下） |

## 分岐の根拠

SKILL.md の実行モード判定表で自然言語依頼による対話モードに該当。description の「MD を PDF に変換」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-01_basic_a4.md](case-01_basic_a4.md): 標準 A4 変換の詳細
- [case-08_trigger_design_doc_pdf.md](case-08_trigger_design_doc_pdf.md): 設計書 PDF 化トリガー
