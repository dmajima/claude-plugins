# Evals: command-toolkit

`command-toolkit` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | 新規コマンド作成（対話） | 引数不足 |
| case-02 | オーケストレータ型コマンド | ルーティング先指定あり |
| case-03 | 既存コマンドの改修 | 同名コマンド既存 |
| case-04 | 命名衝突（既存コマンドファイル） | 配置先に同名 .md あり |
| case-05 | `--non-interactive` モード（質問なしで生成） | `--non-interactive` フラグ |
| case-06 | 非対話モード + 命名衝突の fail-closed | `--non-interactive` + 同名既存 |
| case-07 | argument-hint 必須化（ADR-023） | 引数受取コマンドの frontmatter 検証 |

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイルを必ず追加し、本 README のケース一覧に登録する。詳細は [`../../../references/guides/eval-guide.md`](../../../references/guides/eval-guide.md) を参照。

## 実行確認方法

各ケースは `command-toolkit` の動作分岐を例示する仕様書である。実装側で本ケースを満たすか確認する手順:

1. ケースの「入力」を再現する状態（前提ファイル・フラグ）を整える
2. `command-toolkit` を起動（自然言語フレーズ or `/extension command`）
3. ケースの「期待動作」「期待出力」と実動作が一致することを確認
4. 不整合があれば指摘として記録
