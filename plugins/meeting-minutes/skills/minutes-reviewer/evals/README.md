# Evals: minutes-reviewer

`minutes-reviewer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_with_corrections | 誤帰属・漏れを検出し修正提案を返却する | 修正あり |
| case-02_no_corrections | 正確な議事録に対して修正なし通過する | 修正なし |
| case-03_ailead_source_review | response.json の callSummary.topics の dateTime を起点に時刻ベースで突合検証を実施する | ailead ソース突合 |
| case-04_missing_input | `workspace/minutes.json` 不在時に minutes-composer の起動を提案して中断する | 入力ファイル不在 → 対話 |
| case-05_review_minutes | 作成済みの議事録を文字起こしと突合検証する | 非対話・自動検証 |
| case-06_check_minutes | 議事録の正確性チェックを依頼する | 非対話・自動検証（別フレーズ） |
| case-07_error_empty_minutes | 議事録データが空の状態でレビューを依頼する | 入力不在 → エラー |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、フレッシュなサブエージェントとして起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい検証項目や分岐ロジックを追加した場合は、対応するケースファイルを必ず追加する。
