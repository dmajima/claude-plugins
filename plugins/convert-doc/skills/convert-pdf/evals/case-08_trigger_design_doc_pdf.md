# case-08 設計書を PDF 化

ユーザーが設計書や資料を PDF 形式で出力するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "設計書を PDF 化して" |
| モード | 対話 |

## 期待動作

- convert-pdf スキルが起動する
- 入力 Markdown ファイルの場所を確認する
- HTML 版と同一デザインで mermaid 図・表・コードブロックを含む PDF を生成する
- 最終 PDF をセッションフォルダ直下に出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | HTML 版同一デザインの PDF ファイル（mermaid 図・表・コードブロック含む） |

## 分岐の根拠

SKILL.md の実行モード判定表で自然言語依頼による対話モードに該当。description の「設計書を PDF 化して」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-07_trigger_md_to_pdf.md](case-07_trigger_md_to_pdf.md): 基本的な変換トリガー
- [case-09_trigger_report_pdf_output.md](case-09_trigger_report_pdf_output.md): 資料 PDF 出力トリガー
