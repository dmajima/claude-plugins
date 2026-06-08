# case-52 スライドをテキスト化

ユーザーが PowerPoint スライドをテキスト化するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PowerPoint の資料を読める形にして" |
| モード | 対話 |

## 期待動作

- convert-from-pptx スキルが起動する
- 入力 PPTX ファイルの場所を確認する
- 構造化 JSON 抽出と Markdown 生成の 2 フェーズで処理する
- 最終 Markdown をセッションフォルダ直下に出力する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | 入力 PPTX に対応する Markdown ファイル（セッションフォルダ直下） |

## 分岐の根拠

SKILL.md の実行モード判定表で「上記以外（自然言語依頼）→ 対話モード」に該当。「読める形にして」は PPTX→Markdown 変換の自然言語トリガーであり、description の「PowerPoint を読める形に」パターンに合致。

## 関連ケース

- [case-51_trigger_pptx_to_md.md](case-51_trigger_pptx_to_md.md): 直接的な変換依頼トリガー
- [case-53_trigger_design_doc_parse.md](case-53_trigger_design_doc_parse.md): 設計書解析トリガー
