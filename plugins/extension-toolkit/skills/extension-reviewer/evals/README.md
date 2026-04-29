# Evals: extension-reviewer

`extension-reviewer` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | スキルレビュー（標準観点 3 名） | 対象 = スキル |
| case-02 | プラグインレビュー（5 名） | 対象 = プラグイン |
| case-03 | フックレビュー（security-engineer 必須） | 対象 = フック |
| case-04 | 自動修正モード | `--auto-fix` フラグ |
| case-05 | Critical 検出時の REJECT | パスポータビリティ NG |
| case-06 | CONDITIONAL_APPROVE（High あり Critical なし） | High 指摘 1 件以上 + Critical 0 件 |
