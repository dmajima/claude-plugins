# Evals: hook-creator

`hook-creator` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | プラグイン同梱フック新規作成 | 配置先 = プラグイン |
| case-02 | settings.json への追加 | 配置先 = settings.json |
| case-03 | 既存フックへの追加（マージ） | 既存エントリあり |
| case-04 | 非対話モード | `--non-interactive` フラグあり |
