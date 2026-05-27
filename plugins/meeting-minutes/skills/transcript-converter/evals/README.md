# Evals: transcript-converter

`transcript-converter` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 分岐 | 概要 |
|--------|------|------|
| case-01_vtt_format | VTT パーサー | `.vtt` ファイル入力時に WebVTT パーサーで変換する |
| case-02_srt_format | SRT パーサー | `.srt` ファイル入力時に SRT パーサーで変換する |
| case-03_teams_paste | Teams パターン検出 | Teams コピペテキスト入力時に Teams パーサーで変換する |
| case-04_plain_fallback | プレーンテキスト | パターン不一致時にプレーンテキストとしてフォールバック処理する |
| case-05_missing_metadata | ユーザー確認 | メタデータ（タイトル・日時等）が推定不能な場合にユーザーに確認する |

## 実行確認方法

各ケースの「入力」セクションのフレーズ・ファイルで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい入力形式や分岐ロジックを追加した場合は、対応するケースファイルを必ず追加する。
