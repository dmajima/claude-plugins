# Evals: meeting-minutes コマンド

`commands/minutes-md.md` および `commands/minutes-docx.md` のフルパイプラインコマンドの動作分岐の期待挙動を例示する。

両コマンドはデータ取得ステップの引数判定が共通であるため、ケースファイルは共通化している。
出力形式（Markdown / docx）の違いは最終ステップのみであり、引数判定・パイプライン制御の分岐は同一。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_command_with_ailead_url | ailead 共有 URL を引数に渡した場合に connector:ailead を起動する | ailead URL 引数 |
| case-02_command_with_file | VTT/SRT ファイルパスを引数に渡した場合に transcript-converter を起動する | ファイルパス引数 |
| case-03_command_no_args | 引数なしの場合にユーザーに入力方法を確認する | 引数なし |
| case-04_command_text_paste | テキスト直接貼り付け時に transcript-converter に渡してフルパイプライン実行する | テキスト引数 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで `/minutes-md` または `/minutes-docx` コマンドを起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいデータソースや引数パターンを追加した場合は、対応するケースファイルを必ず追加する。
