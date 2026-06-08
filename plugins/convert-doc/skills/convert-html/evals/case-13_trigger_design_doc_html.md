# case-13 設計書を HTML で出力

ユーザーが設計書や資料を HTML 形式で出力するよう依頼した場合のトリガー。

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "設計書を HTML で出力して" |
| モード | 対話 |

## 期待動作

- convert-html スキルが起動する
- 入力 Markdown ファイルの場所を確認する
- Wiki スタイルの HTML を生成する
- 目次サイドバー・シンタックスハイライトが適用される

## 期待出力

| 出力 | 内容 |
|-----|------|
| 成果物 | Wiki スタイル HTML ファイル（目次サイドバー・シンタックスハイライト適用済み） |

## 分岐の根拠

SKILL.md の実行モード判定表で「`/convert-html` または自然言語依頼 → 対話モード」に該当。description の「設計書を HTML に変換」パターンに合致し、スキルトリガーとして認識される。

## 関連ケース

- [case-12_trigger_md_to_html.md](case-12_trigger_md_to_html.md): 基本的な変換トリガー
- [case-14_trigger_report_html.md](case-14_trigger_report_html.md): 資料 HTML 化トリガー
