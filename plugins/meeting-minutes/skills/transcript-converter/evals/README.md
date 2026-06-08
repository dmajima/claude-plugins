# Evals: transcript-converter

`transcript-converter` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_vtt_format | `.vtt` ファイル入力時に WebVTT パーサーで変換する | VTT パーサー |
| case-02_srt_format | `.srt` ファイル入力時に SRT パーサーで変換する | SRT パーサー |
| case-03_teams_paste | Teams コピペテキスト入力時に Teams パーサーで変換する | Teams パターン検出 |
| case-04_plain_fallback | パターン不一致時にプレーンテキストとしてフォールバック処理する | プレーンテキスト |
| case-05_missing_metadata | メタデータ（タイトル・日時等）が推定不能な場合にユーザーに確認する | ユーザー確認 |
| case-06_ailead_format | ailead 形式の `[HH:MM:SS - HH:MM:SS] 発話者: テキスト` 入力時に ailead パーサーで変換する | ailead パーサー |
| case-07_convert_transcript | Teams の文字起こしコピペから標準形式に変換する | Teams パターン → 対話 |
| case-08_srt_to_standard | SRT ファイルを標準形式に変換する | SRT パーサー（ファイル指定） |
| case-09_error_format_fallback | 形式自動判定が失敗しプレーンテキストフォールバックで処理する | 判定失敗 → フォールバック |

## 実行確認方法

各ケースの「入力」セクションのフレーズ・ファイルで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい入力形式や分岐ロジックを追加した場合は、対応するケースファイルを必ず追加する。
