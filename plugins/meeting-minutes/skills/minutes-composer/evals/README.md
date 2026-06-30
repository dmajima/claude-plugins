# Evals: minutes-composer

`minutes-composer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_ailead_flow | `workspace/response.json` あり時にトピック要約ベースで構造化する | ailead フロー |
| case-02_generic_flow | `response.json` なし時にゼロから構造化する | 汎用フロー |
| case-03_missing_input | `workspace/transcript.txt` 不在時にデータ取得スキルの起動を提案して中断する | 入力ファイル不在 → 対話 |
| case-04_compose_minutes | 取得済みデータから議事録の構成を依頼する | 非対話・自動構造化 |
| case-05_generic_text_minutes | テキストを直接提供して議事録を作成する | 汎用テキスト → 対話 |
| case-06_error_no_input | 入力ファイルが存在しない状態で議事録作成を依頼する | 入力不在 → エラー |
| case-07_ailead_null_summary | ailead フロー判定後、callSummary が null のため generic flow にフォールバックする | ailead + callSummary null → generic flow |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、Claude Code を起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいデータソース（Teams API 等）やフロー分岐を追加した場合は、対応するケースファイルを必ず追加する。
