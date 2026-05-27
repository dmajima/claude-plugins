# Evals: minutes-composer

`minutes-composer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 分岐 | 概要 |
|--------|------|------|
| case-01_ailead_flow | ailead フロー | `workspace/response.json` あり時にトピック要約ベースで構造化する |
| case-02_generic_flow | 汎用フロー | `response.json` なし時にゼロから構造化する |

## 実行確認方法

各ケースの「入力」セクションの前提状態を再現し、Claude Code を起動して「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいデータソース（Teams API 等）やフロー分岐を追加した場合は、対応するケースファイルを必ず追加する。
