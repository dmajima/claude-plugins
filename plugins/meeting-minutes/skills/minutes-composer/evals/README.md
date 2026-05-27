# Evals: minutes-composer

`minutes-composer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_ailead_flow | `workspace/response.json` あり時にトピック要約ベースで構造化する | ailead フロー |
| case-02_generic_flow | `response.json` なし時にゼロから構造化する | 汎用フロー |
| case-03_missing_input | `workspace/transcript.txt` 不在時にデータ取得スキルの起動を提案して中断する | 入力ファイル不在 → 対話 |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、Claude Code を起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいデータソース（Teams API 等）やフロー分岐を追加した場合は、対応するケースファイルを必ず追加する。
