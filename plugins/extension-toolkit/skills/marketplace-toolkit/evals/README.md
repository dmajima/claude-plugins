# Evals: marketplace-toolkit

`marketplace-toolkit` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | マーケットプレイス新規構築 | 対象パスに `marketplace.json` 未存在 |
| case-02 | プラグイン追加 + README 同期 | `--add-plugin` フラグ |
| case-03 | プラグイン削除（明示確認 + ファイル削除選択） | `--remove-plugin` フラグ |
| case-04 | README 同期のみ | `--sync-readme` フラグ |
| case-05 | 重複プラグイン追加の阻止 | 既存と同名プラグイン追加 |
| case-06 | `--non-interactive` モード（質問なしで構築） | `--non-interactive` フラグ |
| case-07 | プラグイン更新（`--update-plugin` モード） | `--update-plugin` フラグ |
| case-08 | 非対話モード + 二段フラグでファイル本体含む削除 | `--non-interactive --remove-plugin --also-delete-files --confirm-destructive` |
| case-09 | 非対話モード + 二段フラグ不揃い時の fail-closed | `--also-delete-files` 単独（`--confirm-destructive` なし）|

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイルを必ず追加し、本 README のケース一覧に登録する。詳細は [`../../../references/eval-guide.md`](../../../references/eval-guide.md) を参照。

## 実行確認方法

各ケースは `marketplace-toolkit` の動作分岐を例示する仕様書である。実装側で本ケースを満たすか確認する手順:

1. ケースの「入力」を再現する状態（前提ファイル・フラグ）を整える
2. `marketplace-toolkit` を起動（自然言語フレーズ or `/extension marketplace`）
3. ケースの「期待動作」「期待出力」と実動作が一致することを確認
4. 不整合があれば指摘として記録
