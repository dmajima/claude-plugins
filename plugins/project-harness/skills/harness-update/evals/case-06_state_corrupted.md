# case-06: .sync-state.json が破損している

## 入力

```text
/project-harness:update
```

前提: `.claude/references/.sync-state.json` は存在するが、JSON としてパース不能、または `last_synced_commit` フィールドが欠落している。

## 期待動作

1. Phase 1 の state 妥当性検査で破損を検出する
2. HEAD での state 再初期化を AskUserQuestion で提案する
3. 承認後: 同期基準が失われているため差分検出は行えず、**全ドキュメントの frontmatter `sources` とソース実体の照合による全量整合チェック** へ切り替えて乖離を洗い出す
4. 整合チェックの反映完了後、`.sync-state.json` を HEAD で再初期化する（`initialized_at` は既存値が読めれば維持、読めなければ現在時刻）
5. `--non-interactive` 併用時: 再初期化は実施せず中断し、破損の事実と対話モードでの再実行を案内する（同期基準の作り直しはユーザ判断が必須のため）

## 期待出力

- 破損検出の報告と再初期化提案
- （承認時）全量整合チェックの結果と state 再初期化の報告

## 禁止事項（このケースで起きてはならないこと）

- 破損 state の無視・無確認上書き
- 破損データから読み取れた不完全な SHA に基づく誤差分計算での反映続行

## 分岐の根拠

procedures.md Phase 1 の検査表「state 妥当性」行。同期基盤そのものの復旧フローであり、通常の差分反映（case-01）とは経路が異なる。

## 関連ケース

- [case-01](case-01_standard_update.md): state が正常な標準差分反映
- [case-07](case-07_unreachable_sha.md): state は正常だが SHA が履歴から失われたケース
