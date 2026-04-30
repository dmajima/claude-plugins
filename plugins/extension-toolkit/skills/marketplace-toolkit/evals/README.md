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
