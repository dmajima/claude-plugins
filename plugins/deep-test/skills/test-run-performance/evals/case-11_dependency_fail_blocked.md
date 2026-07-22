# case-11 依存先ケース fail → 後続ケース blocked

`depends_on` で依存を宣言した性能ケースの依存先が同一 run 内で fail するケース。後続ケースを計測せず blocked + reason（依存先ケース ID とその結果）で記録することを検証する。既存 functional/scenario の同型ケース（依存元 fail → 後続 blocked）を performance レベルで確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260722-130000 / 対象ケース TC-PERF-001（一覧画面の初期表示応答時間。閾値超過で fail になる）・TC-PERF-002（depends_on: [TC-PERF-001]。一覧表示成立を前提とする絞り込み操作の応答時間）/ 対象 URL https://localhost:5001 |
| 起動形態 | 委譲（オーケストレータ test から Skill ツール経由・MCP ゲート通過済み） |
| 前提 | MCP 利用可・対象機能が機能レベルで安定動作。TC-PERF-001 が閾値超過により fail する状態 |

## 分岐の根拠

SKILL.md「実行フロー」（preconditions 確認: 計測条件の準備）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md`（依存元 fail 時、後続ケースは blocked + reason で記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（depends_on）・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked の意味論: 依存ケースの fail）、`${CLAUDE_SKILL_DIR}/references/performance-execution.md`（計測手順・閾値判定）。

## 期待動作

- TC-PERF-001 の応答時間を既定 3 回計測し中央値を採用、閾値超過で fail と判定して `extras.measured_value` / `extras.threshold` を記録、severity を severity-policy.md 4.1（閾値超過率バンド）で判定して defect 3 点セットを収集する
- TC-PERF-002 の計測前に depends_on を確認し、依存先（TC-PERF-001）が同一 run 内で fail であることを検出する
- TC-PERF-002 の応答時間計測を実行せず **blocked** と判定し、reason に依存先ケース ID（TC-PERF-001）とその結果（fail）を記録する
- blocked のケースに defect・severity・measured_value を付与しない（計測していないため実測値を捏造しない）
- 依存先が fail でも後続を強行計測しない（前提が崩れた状態の計測値を実績にしない）
- scope 全件（2 エントリ: fail 1 件 + blocked 1 件）を返却する
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | TC-PERF-001 の fail 証跡（計測値生データ JSON・スクリーンショット）を evidence/R20260722-130000/TC-PERF-001/ へ移送・保存（TC-PERF-002 は計測しないためエビデンスなし）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-performance" / 受領 run_id / results 2 件。fail エントリは extras.measured_value・extras.threshold・severity 付き defect、blocked エントリは依存先 ID と結果を記した reason 付き）。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 2 件を 1 エントリずつ返却（TC-PERF-001 fail / TC-PERF-002 blocked＝依存先 fail。後続の強行計測なし） |

## 関連ケース

- case-01: 応答時間計測と閾値判定（計測そのもの）
- case-03: 負荷ツール未検出による多重負荷の skipped（skipped の別要因）
- case-07: 応答不能による blocked（blocked の別要因）
- test-run-functional case-05 / test-run-integration case-13: 他レベルの同型（依存元 fail → 後続 blocked）
