<!-- TEST-RUN-SCN-EVAL-ENDPOINTS-SENTINEL-v1 -->
# case-15 environment.yaml の endpoints[] 由来 base URL を対象アプリ情報として受領してシナリオ実行

オーケストレータが test-environment（Phase 1.7）の environment.yaml `endpoints[]` から得た base URL（テスト用派生環境・127.0.0.1 バインド）を「対象アプリ情報（URL 等）」として受領し、既存の受領形・実行手順のまま業務シナリオを通しで実行することを検証する。出所が environment.yaml 由来でも、受領形・シナリオ実行・途中 fail 判断・エビデンス収集に変化がない（出所の注記のみ）ことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-152000 / 対象ケース TC-SYS-001（automation: playwright・業務シナリオ通し）/ 対象 URL `http://127.0.0.1:18080`（environment.yaml の `endpoints[]` 由来・`purpose: browser`・`health: healthy`） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | test-environment の action=up が完了済みで `endpoints[]` が確定している（up・health 確認は test-environment / オーケストレータの責務。本スキルは base URL の受領のみ）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「前提」（対象アプリ情報〔URL 等〕は environment.yaml の `endpoints[]` 由来の base URL として受領する場合がある。受領形・実行手順は不変・出所の注記のみ）、`${CLAUDE_SKILL_DIR}/references/scenario-execution.md` 1 章（前段: 入力の解決と整列）・2 章（1 ケース〔1 シナリオ〕の実行手順）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 8 章（endpoints[]）。

## 期待動作

- 受領した base URL（`http://127.0.0.1:18080`）を通常の「対象アプリ情報（URL 等）」と同一の受領形として扱い、シナリオ実行手順（scenario-execution.md 2 章）を既存手順どおり実施する（出所による特別扱い・分岐追加をしない）
- シナリオの完遂状況（どのステップまで到達したか）の actual 記録・途中 fail 時の後続判断（同 3 章）は既存規範のまま
- environment.yaml を書き換えない（`endpoints[]` は受領材料。生成・更新は test-environment の専有）
- 環境の up / down・health 判定を本スキルで行わない（稼働状態の管理は test-environment / オーケストレータの責務）
- ステップごとのエビデンス取得・即時移送・`executed_by: playwright-mcp` の記録は既存規範のまま
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-152000/TC-SYS-001/` 配下にステップごとのスクリーンショット（既存命名）。environment.yaml / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: playwright-mcp）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-SYS-001）を 1 エントリで返却（ユーザー起動 URL を受領した場合と同一の動作） |

## 関連ケース

- case-01: ユーザー起動 URL での業務シナリオ通し pass（受領形・実行手順が同一であることの対比）
- case-05: Playwright MCP 未ロードによる skipped（endpoints[] 由来 URL でも実行手段の判定は既存のまま）
