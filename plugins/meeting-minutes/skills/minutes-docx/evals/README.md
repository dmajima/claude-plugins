# Evals: minutes-docx

`minutes-docx` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_normal | 正常な minutes.json から docx ファイルを生成する | 正常変換 |
| case-02_missing_input | minutes.json が存在しない場合にエラーを報告する | 入力不在エラー |
| case-03_generate_word | 構造化議事録データから Word ファイルを生成する基本フロー | 正常変換 |
| case-04_docx_output | 議事録作成後に docx 変換を依頼する | 正常変換（別フレーズ） |
| case-05_error_no_json | minutes.json 不在時に minutes-composer の実行を提案する | 入力不在 → エラー |
| case-06_participants_order | 出席者欄の並び順（顧客先・自社最後）・敬称（顧客のみ様）・bot 除外 | 出席者整形仕様 |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、Claude Code を起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい出力形式や分岐ロジックを追加した場合は、対応するケースファイルを必ず追加する。
