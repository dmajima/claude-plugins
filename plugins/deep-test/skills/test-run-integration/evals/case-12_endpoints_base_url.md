<!-- TEST-RUN-ITG-EVAL-ENDPOINTS-SENTINEL-v1 -->
# case-12 environment.yaml の endpoints[] 由来 base URL を IT-a の対象 URL として受領して実行

オーケストレータが test-environment（Phase 1.7）の environment.yaml `endpoints[]` から得た base URL（テスト用派生環境・127.0.0.1 バインド）を IT-a の対象 URL として受領し、既存の受領形・実行手順のまま Playwright MCP 経路で実行することを検証する。出所が environment.yaml 由来でも、受領形・実行フロー・データ突合・エビデンス収集に変化がない（出所の注記のみ）ことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-151000 / 対象ケース TC-ITA-001（automation: playwright・画面経由のモジュール間連携）/ 対象 URL `http://127.0.0.1:18080`（environment.yaml の `endpoints[]` 由来・`purpose: browser`・`health: healthy`） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | test-environment の action=up が完了済みで `endpoints[]` が確定している（up・health 確認は test-environment / オーケストレータの責務。本スキルは base URL の受領のみ）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「前提」（IT-a / IT-b の対象 URL は environment.yaml の `endpoints[]` 由来の base URL として受領する場合がある。受領形・実行手順は不変・出所の注記のみ）、`${CLAUDE_SKILL_DIR}/references/integration-execution.md` 1 章（IT-a の実行手順: 画面経由の連携確認・登録値と参照値の突合）・5 章（エビデンス: 画面 + API レスポンス）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 8 章（endpoints[]）。

## 期待動作

- 受領した base URL（`http://127.0.0.1:18080`）を通常の対象 URL と同一の受領形として扱い、IT-a の実行手順（integration-execution.md 1 章）を既存手順どおり実施する（出所による特別扱い・分岐追加をしない）
- モジュール間のデータ突合（登録値と参照値の照合）・actual への記録は既存規範のまま
- environment.yaml を書き換えない（`endpoints[]` は受領材料。生成・更新は test-environment の専有）
- 環境の up / down・health 判定を本スキルで行わない（稼働状態の管理は test-environment / オーケストレータの責務）
- エビデンス取得・即時移送・`executed_by: playwright-mcp` の記録は既存規範のまま
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-151000/TC-ITA-001/` 配下に画面スクリーンショット等（既存命名）。environment.yaml / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・executed_by: playwright-mcp）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-ITA-001）を 1 エントリで返却（ユーザー起動 URL を受領した場合と同一の動作） |

## 関連ケース

- case-01: ユーザー起動 URL での IT-a 画面間遷移フロー pass（受領形・実行手順が同一であることの対比）
- case-07: Playwright MCP 未ロードによる skipped（endpoints[] 由来 URL でも実行手段の判定は既存のまま）
