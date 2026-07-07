# Case 11: トリガー確認 — 設計書を PPTX で出力

ユーザーが設計書を PowerPoint 形式で出力するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "設計書を PPTX で出力して" |
| モード | 対話 |

## 期待動作

- convert-pptx スキルが起動する
- 入力 Markdown ファイルの場所を確認する
- H1 タイトルスライド + H2 セクション別スライドの構成で PPTX を生成する
- 表は PowerPoint ネイティブテーブル、mermaid 図は PNG として配置する

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | H1/H2 構造の PPTX ファイル（ネイティブテーブル・mermaid PNG 配置） |

## 分岐の根拠

SKILL.md の実行モード判定表で自然言語依頼による対話モードに該当。description の「設計書を PPTX で出力」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-09_trigger_md_to_pptx.md](case-09_trigger_md_to_pptx.md): 基本的な変換トリガー
- [case-05_aspect_4_3.md](case-05_aspect_4_3.md): アスペクト比指定時の対比
