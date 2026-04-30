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
| case-09 | setup 失敗系（Python 未インストール） | `python3` / `python` PATH 不在 |

## 実行確認方法

各ケースは `environment-setup-toolkit` の動作分岐を例示する仕様書である。実装側で本ケースを満たすか確認する手順:

1. ケースの「入力」を再現する状態（前提ファイル・フラグ）を整える
2. `environment-setup-toolkit` を起動（自然言語フレーズ or `/extension setup`）
3. ケースの「期待動作」「期待出力」と実動作が一致することを確認
4. 不整合があれば指摘として記録
