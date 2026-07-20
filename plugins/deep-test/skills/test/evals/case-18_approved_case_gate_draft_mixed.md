# case-18 承認済みケースゲート（select 結果に draft 混入 → test-review 設計文脈を先行 → approved 後に Phase 4 復帰）

再テスト・run-only のように設計フェーズ（Phase 2〜3）を経ずに Phase 4 から始まるモードで、`select` の結果に `review_status: draft` のケースが 1 件混入していた場合、承認済みケースゲートが run を開始せず test-review（設計文脈）を **draft ケースに対して先行実施** し、approved 化後に `select` を再実行して Phase 4 のゲート列（人間承認 → MCP）へ復帰することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「NG だけ再テストして」（`retest ng-only`）または「functional だけ実行して」（`run-only levels=functional`） |
| 前提 | `{base}/{target-slug}/` に approved 済み test-cases.yaml が存在し環境検証済み。ただし 1 件のケースが前回承認後に内容変更され `revision` +1・`review_status: draft` に戻っている（例: TC-FUNC-003）。他のケースは approved。Playwright MCP はロード済み |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.2 章（承認済みケースゲート: scope に `review_status: draft` のケースが含まれる場合、run を開始せず先に test-review〔設計文脈〕を要求。全ケース approved で通過）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（`Phase4 --> Phase3: 承認済みケースゲート（draft 混入）`）・3 章のゲート判定手順（承認済みケースゲート: `select` 出力の `draft_cases` が非空 → test-review〔設計文脈〕を draft ケースに対して実施〔PASS 時の approved 化は test-review が実施〕→ `select` を再実行して確認。不通過時の遷移は Phase 3〔対象は draft ケースのみ〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」Phase 4（承認済みケースゲート）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 8 章（select を経ない対象確定の禁止）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（内容変更で revision +1・draft 戻し）。

## 期待動作

- Phase 4 で `results_manager.py select`（ng-only / ids / full）を実行し、出力の `cases` と `draft_cases` を確認する（LLM の判断で対象を確定しない。retest-policy.md 8 章）
- `draft_cases` に TC-FUNC-003 が含まれるため **承認済みケースゲートを不通過**とし、run を開始しない（`start-run` を実行しない）
- 承認済みケースゲートの遡行として、**test-review（設計文脈）を draft ケースのみを対象に先行実施**する（`Skill(deep-test:test-review, context=design scope=TC-FUNC-003 ...)`）。scope を draft ケースに限定し、既に approved のケースを再レビューしない
- test-review が **PASS** を返した場合、draft ケースの `review_status` は test-review が approved 化する（オーケストレータは test-cases.yaml を編集しない）
- approved 化後に `select` を**再実行**して `draft_cases` が空になったことを確認してからゲートを通過する（件数の推定で通過しない）
- ゲート通過後は Phase 4 の残りのゲート列（人間承認ゲート → MCP ゲート）へ復帰し、通過後に `start-run` で run_id を採番して Phase 5 へ進む
- test-review が **NEEDS REVISION** を返した場合は、draft ケースについて設計修正ループ（flow.md 4.1 章・上限 3 回）へ入り、run へは進まない
- 設計フェーズを最初から起動し直さない（対象は混入した draft ケースのみ。approved 済みケースの設計はやり直さない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-review により TC-FUNC-003 が approved 化された test-cases.yaml（PASS 時）。ゲート通過後に start-run 以降で更新される test-results.yaml。ゲート不通過のまま停止する場合は実績を更新しない |
| 標準出力（要約） | 承認済みケースゲートで draft 混入を検出し test-review（設計文脈）を先行した旨・approved 化後に select 再実行で通過した旨。以降は通常の run 引き渡し（run_id・集計） |
| 終了状態 | PASS 時: ゲート通過 → Phase 5 実行完了。NEEDS REVISION 時: 設計修正ループへ遷移し run 未開始 |

## 関連ケース

- case-02: 再テスト ng-only（全ケース approved 済みで承認済みケースゲートを素通りする主系との対比）
- case-08: run-only（同じく Phase 4 開始モード。draft 混入がない通常系）
- case-04: 設計レビューゲートの NEEDS REVISION 修正ループ（Phase 3 の遡行という点で類似だが、こちらはフルフローの設計文脈起点）
