# Evals: skill-creator

`skill-creator` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 新規・対話モード | 引数不足、スキル名のみ |
| case-02 | 新規・非対話モード | `--non-interactive` + 全パラメータ指定 |
| case-03 | 既存スキル改修 | スキル名が既存 |
| case-04 | Python venv 付き | `--python` フラグあり |
| case-05 | 外部依存スキル参照 | `--external-deps example-skills` |
| case-06 | 動作分岐なし（evals 省略） | `--no-branching` |
| case-07 | エラー系（命名衝突 / 配置先未存在） | 既存スキル名 + 新規作成依頼 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイルを必ず追加する。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) を参照。
