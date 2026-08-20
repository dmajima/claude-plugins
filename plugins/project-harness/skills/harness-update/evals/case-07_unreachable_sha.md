# case-07: rebase 等で last_synced_commit が到達不能

## 入力

```text
/project-harness:update
```

前提: `.sync-state.json` は valid だが、`last_synced_commit` の SHA が rebase / force-push により履歴から失われている（`git cat-file -e <sha>^{commit}` が失敗する）。

## 期待動作

1. Phase 1 の SHA 到達可能性検査で到達不能を検出する
2. 代替の同期基準（`git merge-base` で求めた共通祖先の候補 / ユーザ指定コミット）を AskUserQuestion で確認する
3. 基準確定後、その基準からの差分取得で Phase 2 以降を通常どおり実行する
4. 完了時に `.sync-state.json` を HEAD で更新する（以後は正常な基準に復旧）
5. `--non-interactive` 併用時: 基準の再選定は実施せず中断し、到達不能の事実と対話モードでの再実行を案内する（同期基準の変更はユーザ判断が必須のため）

## 期待出力

- 到達不能の検出報告と基準候補の提示
- 確定した基準による反映結果

## 禁止事項（このケースで起きてはならないこと）

- 到達不能な SHA のまま差分計算を強行すること（誤った全量新規判定・差分ゼロ判定を招く）
- 無確認での同期基準の変更

## 分岐の根拠

procedures.md Phase 1 の検査表「SHA 到達可能性」行。state 自体は正常なため case-06（破損）とは復旧手段が異なる（再初期化ではなく基準の再選定）。

## 関連ケース

- [case-06](case-06_state_corrupted.md): state 自体が破損しているケース
- [case-01](case-01_standard_update.md): SHA が到達可能な標準差分反映
