<!-- TEST-RUN-SEC-EVAL-ENDPOINTS-SENTINEL-v1 -->
# case-13 environment.yaml の endpoints[] 由来 base URL を対象として受領して観点別チェック実行

オーケストレータが test-environment（Phase 1.7）の environment.yaml `endpoints[]` から得た base URL（テスト用派生環境・127.0.0.1 バインド）を対象として受領し、既存の受領形・実行手順のまま観点別チェックを実行することを検証する。テスト用派生環境は「対象はテスト環境」という本スキルの前提に合致する対象であり、出所が environment.yaml 由来でも操作境界・承認済みケース記載の範囲限定・マスキング規範に変化がない（出所の注記のみ）ことを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | target-slug=sample-web / run_id=R20260719-154000 / 対象ケース TC-SEC-001（automation: playwright・セキュリティヘッダ確認）/ 対象 URL `http://127.0.0.1:18080`（environment.yaml の `endpoints[]` 由来・`purpose: browser`・`health: healthy`） |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 対象はテスト用派生環境（`{slug}-test` の分離名前空間・127.0.0.1 バインド）。test-environment の action=up が完了済みで `endpoints[]` が確定している（up・health 確認は test-environment / オーケストレータの責務。本スキルは base URL の受領のみ）。Playwright MCP はロード済み |

## 分岐の根拠

SKILL.md「前提」（対象アプリ情報〔URL 等〕は environment.yaml の `endpoints[]` 由来の base URL として受領する場合がある。受領形・実行手順は不変・出所の注記のみ）、`${CLAUDE_SKILL_DIR}/references/security-execution.md` 0 章（実行してよい操作 / 禁止操作の境界）・1 章（前段: 環境・範囲・MCP の確認）・2 章（観点別チェック手順）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` 8 章（endpoints[]）。

## 期待動作

- 受領した base URL（`http://127.0.0.1:18080`）を通常の対象と同一の受領形として扱い、観点別チェック（security-execution.md 2 章）を既存手順どおり実施する（出所による特別扱い・分岐追加をしない）
- 実行してよい操作 / 禁止操作の境界（同 0 章）・承認済みケース記載の範囲限定は、テスト用派生環境が対象でも**不変**（範囲外の攻撃的操作を追加しない）
- environment.yaml を書き換えない（`endpoints[]` は受領材料。生成・更新は test-environment の専有）
- 環境の up / down・health 判定を本スキルで行わない（稼働状態の管理は test-environment / オーケストレータの責務）
- エビデンス中の機微情報マスキング（同 5 章）・`extras.owasp_category` の記録・`executed_by: playwright-mcp` は既存規範のまま
- 中間結果 JSON を返却し、test-results.yaml への書き込みを行わない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-154000/TC-SEC-001/` 配下にチェック記録（マスク済み・既存命名）。environment.yaml / test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 1 件・executed_by: playwright-mcp）を 1 コードブロックで返却。機微情報はマスク済み。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-SEC-001）を 1 エントリで返却（ユーザー起動 URL を受領した場合と同一の動作） |

## 関連ケース

- case-01: ユーザー起動 URL でのセキュリティヘッダ欠如検出 fail（チェック手順・owasp_category 記録が同一であることの対比）
- case-05: Playwright MCP 未ロードによる skipped（endpoints[] 由来 URL でも実行手段の判定は既存のまま）
- case-06: 破壊的操作・対象外領域の skipped（テスト用派生環境が対象でも操作境界は不変であることの対比）
