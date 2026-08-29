# case-21: ハーネス実体あり・state 不在での起動（state 初期化の提案）

## 入力

```text
/project-harness:update
```

前提: `.claude/references/` の実体（`CLAUDE.md`・ドキュメント群）は存在するが `.claude/references/.sync-state.json` が無い（spec-first でコミット前に構築され、初回コミットが見送られた後にユーザがコミットした状態等）。コミットは 1 件以上存在する。

## 期待動作

1. Phase 1 のコミット有無検査を通過する（コミット 0 件の場合は本ケースではなく中断・案内となる）
2. ハーネス存在検査で「ハーネス実体あり・state 不在」を検出する（sync-spec.md 節 1 の該当状態）
3. `AskUserQuestion` で **HEAD での state 初期化** の可否を確認する
4. 承認後、全量監査モード（Phase 2F）で `references/` 配下全ドキュメントの記載とソース実態を突合してから、`.sync-state.json` を HEAD で確立する
5. 非対話モードでは state 初期化を実施せず中断し、対話モードでの再実行を案内する

## 期待出力

- 「ハーネス実体あり・state 不在」の検出と、この状態の説明（鮮度検知が無干渉のままになる旨）
- state 初期化 + 全量監査の結果（通常モードの Phase 3 以降と同様の反映計画・検証結果）

## 禁止事項（このケースで起きてはならないこと）

- 「ハーネス未構築」と誤判定して `harness-init` への切替のみを案内すること（実体があるため、コード解析ベースの再構築マージは spec-first の `draft` 群を毀損しうる）
- 無確認での state 生成
- 存在しない SHA・プレースホルダ文字列での state 初期化
- 非対話モードでの state 初期化の実施

## 分岐の根拠

procedures.md Phase 1 の検査表「ハーネス存在」行（実体あり・state 不在の分岐）と「コミット有無」行、sync-spec.md 節 1「ハーネス実体あり・state 不在の状態」の復旧経路 (b)。

## 関連ケース

- [case-03](case-03_harness_missing.md): state も実体も無い場合（init / define への切替案内）
- [case-06](case-06_state_corrupted.md): state はあるが破損している場合（同じく HEAD 再初期化 + 2F の経路）
- （harness-define 側）case-06: 本ケースの前提を作る初回コミット拒否経路と、define 再実行による復旧経路 (a)
