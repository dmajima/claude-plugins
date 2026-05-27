# Evals: meeting-minutes コマンド

`commands/minutes-md.md` および `commands/minutes-docx.md` のフルパイプラインコマンドの動作分岐の期待挙動を例示する。

両コマンドはデータ取得ステップの引数判定が共通であるため、ケースファイルは共通化している。
出力形式（Markdown / docx）の違いは最終ステップのみであり、引数判定・パイプライン制御の分岐は同一。

## ケース一覧

| ケース | 分岐 | 概要 |
|--------|------|------|
| case-01_command_with_ailead_url | ailead URL 引数 | ailead 共有 URL を引数に渡した場合に ailead-fetcher を起動する |
| case-02_command_with_file | ファイルパス引数 | VTT/SRT ファイルパスを引数に渡した場合に transcript-converter を起動する |
| case-03_command_no_args | 引数なし | 引数なしの場合にユーザーに入力方法を確認する |

## 実行確認方法

各ケースの「入力」セクションのフレーズで `/minutes-md` または `/minutes-docx` コマンドを起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいデータソースや引数パターンを追加した場合は、対応するケースファイルを必ず追加する。
