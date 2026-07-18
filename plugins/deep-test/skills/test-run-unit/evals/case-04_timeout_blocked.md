# case-04 ケースタイムアウト超過 → blocked

テスト実行がハングしケースタイムアウトを超過するケース。blocked + reason（経過時間・最後に完了したステップ）で記録し、次ケースへ継続することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-api / run_id=R20260717-163000 / 対象ケース TC-UNIT-001（timeout_sec: 60・対応テストが無限ループでハングする）・TC-UNIT-002（正常に成功する） |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | pytest 基盤あり。TC-UNIT-001 の対応テストが応答を返さない状態。ケース単位の duration 制御のためケース別実行方式を選択する状況 |

## 分岐の根拠

SKILL.md「実行フロー」手順 5、references/unit-execution.md 3.2（タイムアウト制御）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 8 章（タイムアウト: 超過時は blocked + reason 記録し次ケースへ）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: ケースタイムアウトによるハング）。

## 期待動作

- ケースの `timeout_sec`（60 秒）を Bash の timeout 制御に反映して実行する（既定 120 秒を上書き）
- 超過時に TC-UNIT-001 を blocked と判定し、reason にタイムアウト発生の旨・経過時間・最後に完了したステップを記録する
- blocked に defect・severity を付与しない（severity は fail のみ。severity-policy.md 1 章）
- ハングした実行を打ち切ったあと、TC-UNIT-002 の実行を継続し結果を記録する（run 全体を中断しない）
- scope 全件（2 エントリ）を返却する（blocked でも欠落させない）
- タイムアウトを skipped や fail と混同しない（blocked = テスト論理・実行制御上のブロック）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 実行できたケースの実行ログを evidence/R20260717-163000/{case_id}/90_runner-log.txt へ保存（blocked の TC-UNIT-001 には defect 証跡を作らない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件。blocked エントリは reason に経過時間・最後に完了したステップを記載し defect・severity なし）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-UNIT-001 blocked / TC-UNIT-002 pass。run 全体は中断しない） |

## 関連ケース

- case-02: fail の分岐（defect 収集あり）
- case-03: skipped の分岐（実行手段不在）
