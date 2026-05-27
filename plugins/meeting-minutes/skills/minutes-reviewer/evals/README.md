# Evals: minutes-reviewer

`minutes-reviewer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 分岐 | 概要 |
|--------|------|------|
| case-01_with_corrections | 修正あり | 誤帰属・漏れを検出し修正提案を返却する |
| case-02_no_corrections | 修正なし | 正確な議事録に対して修正なし通過する |
| case-03_ailead_source_review | ailead ソース突合 | response.json の callSummary.topics の dateTime を起点に時刻ベースで突合検証を実施する |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、フレッシュなサブエージェントとして起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい検証項目や分岐ロジックを追加した場合は、対応するケースファイルを必ず追加する。
