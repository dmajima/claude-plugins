# case-11 依存先ケース fail → 後続ケース blocked

`depends_on` で依存を宣言したユニットケースの依存先が同一 run 内で fail するケース。後続ケースを実行済みとして扱わず blocked + reason（依存先ケース ID とその結果）で記録することを検証する。既存 functional/scenario の同型ケース（依存元 fail → 後続 blocked）を unit レベルで確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-api / run_id=R20260722-110000 / 対象ケース TC-UNIT-001（共通初期化ユーティリティのテスト。実行すると fail になる）・TC-UNIT-002（depends_on: [TC-UNIT-001]。初期化成立を前提とするテスト） |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由） |
| 前提 | テストランナー（pytest 等）検出済み・テストコード参照可。TC-UNIT-001 に対応するテストが欠陥により fail する状態 |

## 分岐の根拠

SKILL.md「実行フロー」手順 3（ケース実行の共通手順: preconditions 確認 → 照合）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md`（依存元 fail 時、後続ケースは blocked + reason で記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（depends_on）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: 依存ケースの fail）、`${CLAUDE_SKILL_DIR}/references/unit-execution.md`（ランナー実行・ケースマッピングの手順。マッピング後に依存関係を反映する）。

## 期待動作

- TC-UNIT-001 に対応するテストを実行して fail と判定し、defect 3 点セット（環境情報含む再現手順・検証データ・実行ログ / スタックトレース）と `extras.stack_trace` を収集する（case-02 と同じ fail 処理）
- TC-UNIT-002 の結果を確定する前に depends_on を確認し、依存先（TC-UNIT-001）が同一 run 内で fail であることを検出する
- TC-UNIT-002 を **blocked** と判定し、reason に依存先ケース ID（TC-UNIT-001）とその結果（fail）を記録する（ランナーが当該テストを実行していても、依存元 fail のため結果を pass/fail として採用せず blocked とする）
- blocked のケースに defect・severity を付与しない
- 依存先が fail の後続ケースを pass として報告しない（依存前提が崩れた状態の見かけ上の成功を実績にしない）
- scope 全件（2 エントリ: fail 1 件 + blocked 1 件）を返却する
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-UNIT-001 の fail 証跡（ランナー実行ログ・スタックトレース）を evidence/R20260722-110000/TC-UNIT-001/ へ保存（TC-UNIT-002 は結果を採用しないためエビデンスは依存元の記録に留める）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-unit" / 受領 run_id / results 2 件。fail エントリは severity・extras.stack_trace 付き defect、blocked エントリは依存先 ID と結果を記した reason 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-UNIT-001 fail / TC-UNIT-002 blocked＝依存先 fail） |

## 関連ケース

- case-02: fail 処理そのもの（3 点セット収集・スタックトレース）
- case-04: タイムアウトによる blocked（blocked の別要因）
- test-run-functional case-05 / test-run-integration case-13: 他レベルの同型（依存元 fail → 後続 blocked）
