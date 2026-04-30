# Evals: environment-setup-toolkit

`environment-setup-toolkit` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | setup（新規 venv 構築） | venv 不在 + requirements.txt あり |
| case-02 | setup（既存 venv 再利用） | venv 既存 |
| case-03 | teardown（venv 削除） | 動作 = teardown |
| case-04 | refresh（再構築） | 動作 = refresh |
| case-05 | check（状態確認） | 動作 = check |
| case-06 | エラー系（範囲外パスでの teardown） | 安全装置作動 |
| case-07 | setup（requirements.txt 不在 / 指定なし） | `--requirements` 省略 |
| case-08 | 非対話モード（全パラメータ引数指定） | `--non-interactive` フラグ |
