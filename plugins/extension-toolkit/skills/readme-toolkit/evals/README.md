# Evals: readme-toolkit

`readme-toolkit` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | プラグイン README 新規作成 | プラグイン対象 + README 未存在 |
| case-02 | スキル README 更新 | スキル対象 + README 既存 |
| case-03 | 過去履歴除去 | 既存 README に履歴記載あり |
| case-04 | `--non-interactive` モード（自動抽出して書き戻し） | `--non-interactive` フラグ |
