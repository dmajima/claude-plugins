<!-- TEST-RUN-FUNC-EVAL-ENDPOINTS-SENTINEL-v1 -->
# case-11 environment.yaml の endpoints[] 由来 base URL を対象アプリ情報として受領して実行

オーケストレータが test-environment（Phase 1.7）の environment.yaml `endpoints[]` から得た base URL（テスト用派生環境・127.0.0.1 バインド）を「対象アプリ情報（URL 等）」として受領し、既存の受領形・実行手順のまま Playwright MCP 経路で実行することを検証する。出所が environment.yaml 由来でも、受領形・実行フロー・照合・エビデンス収集に変化がない（出所の注記のみ）ことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-150000 / 対象ケース TC-FUNC-001（automation: playwright）/ 対象 URL `http://127.0.0.1:18080`（environment.yaml の `endpoints[]` 由来・`purpose: browser`・`health: healthy`） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | test-environment の action=up が完了済みで `endpoints[]` が確定している（up・health 確認は test-environment / オーケストレータの責務。本スキルは base URL の受領のみ）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「前提」（対象 URL は environment.yaml の `endpoints[]` 由来の base URL として受領する場合がある。受領形・実行手順は不変・出所の注記のみ）、SKILL.md「実行フロー」1〜8（既存の MCP 経路のまま。出所による分岐を追加しない）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 8 章（endpoints[]）、`${CLAUDE_SKILL_DIR}/references/functional-execution.md` 1〜3 章（操作対応付け・照合・エビデンス取得/移送）。

## 期待動作

- 受領した base URL（`http://127.0.0.1:18080`）を通常の「対象アプリ情報（URL 等）」と同一の受領形として扱い、browser_navigate の到達確認から実行フロー 1〜8 を既存手順どおり実施する（出所による特別扱い・分岐追加をしない）
- environment.yaml を書き換えない（`endpoints[]` は受領材料。生成・更新は test-environment の専有）
- 環境の up / down・health 判定を本スキルで行わない（稼働状態の管理は test-environment / オーケストレータの責務）
- ステップごとのエビデンス取得・即時移送・expected 照合・`executed_by: playwright-mcp` の記録は既存規範のまま
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-150000/TC-FUNC-001/` 配下にステップごとのスクリーンショット（`{case_id}_{NN}_{label}.png` の既存命名）。environment.yaml / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件・executed_by: playwright-mcp）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-FUNC-001）を 1 エントリで返却（ユーザー起動 URL を受領した場合と同一の動作） |

## 関連ケース

- case-01: ユーザー起動 URL を受領した画面操作 pass（受領形・実行手順が同一であることの対比）
- case-03: 対象 URL 不達 blocked（endpoints[] 由来 URL でも到達確認・status 分岐は既存のまま）
