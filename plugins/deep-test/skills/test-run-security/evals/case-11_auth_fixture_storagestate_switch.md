# case-11 automation: playwright-test 実走 pass（認証フィクスチャ storageState で認証済み/未認証を切替え認可挙動を pass 検証）

`automation: playwright-test` の security ケースについて、fixtures.yaml の認証フィクスチャ（`type: auth`・storageState）と SUT テストコードを前提に `npx playwright test`（Bash 実行）で実走し、認証済み context（storageState 再利用）と未認証 context（storageState なし）で保護リソースへの到達可否の挙動差を非破壊で検証して、認可挙動が全て期待どおり（未認証は遮断・認証済みは到達）で **pass** となることを JUnit / レポートからエビデンス化し `executed_by: playwright-test` で記録することを検証する。既存の MCP・`curl` 経路と併存し、0 章の非破壊境界を不変で守ることを確認する。実行手段不在時の skipped は case-12 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-110000` / 対象ケース `TC-SEC-020`（`automation: playwright-test`・`fixtures: [authenticatedPage]`。保護リソースの未認証アクセス制御を認証済み/未認証で対検証）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | `fixtures.yaml`（`type: auth` の `authenticatedPage` と storageState 保存 setup を含む）と SUT テストコード（`.spec.ts` / `playwright.config.ts`・認証済み/未認証プロジェクト）が test-fixture により生成済み。対象はテスト環境。`npx playwright test` が実行可能で、認可挙動は期待どおり（欠陥なし・全 pass） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: 認証フィクスチャ storageState で認証済み/未認証を切替え `npx playwright test` で実走・`executed_by: playwright-test`）、SKILL.md「実行フロー」の playwright-test 実走経路、`${CLAUDE_SKILL_DIR}/references/security-execution.md` 7 章（前提・認証フィクスチャ storageState を用いた認証済み/未認証の切替テスト・結果マッピング〔7.3: 期待どおりの認可挙動で pass〕とエビデンス化）・0 章（非破壊の操作境界は不変）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 3.1（認証 storageState）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by: playwright-test）・7 章（テストランナー実行時のエビデンス）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 4.2（OWASP 対応表）。

## 期待動作

- ケースの `automation: playwright-test` を検出し、`npx playwright test`（Bash）で対象 `.spec.ts` を認証済み / 未認証の 2 プロジェクトで実走する（`--project=authenticated --project=unauthenticated`）
- 認証済み context は fixtures.yaml の認証フィクスチャの storageState を再利用し、未認証 context は storageState を与えず（新規 context）に実走する
- 保護リソースへの到達可否の挙動差を検証する（未認証は遮断〔リダイレクト / 401 / 403〕・認証済みは到達可が期待どおりか）。**到達可否の観察に留め、到達後にデータを改変しない**（0 章の非破壊境界は不変。破壊的攻撃・範囲外操作を行わない）
- SUT テストコード・`playwright.config.ts` を生成・改変しない（実走のみ。生成は test-fixture の責務）
- 認可挙動が全て期待どおり（未認証は遮断・認証済みは到達）のため status を **pass** とする（未認証で保護リソースに到達等の欠陥検出時 fail〔`extras.owasp_category` 記録・severity は severity-policy.md 4.2 で判定〕/ 設定エラーで未実行時 blocked + reason の status マッピングは security-execution.md 7.3 を正とするが、本ケースは pass の主系）
- エビデンス（stdout / stderr ログ・JUnit XML・HTML レポート）を `evidence/R20260719-110000/TC-SEC-020/` へ保存し、**storageState 値・トークン・Set-Cookie 等の機微情報を保存前にマスクする**（生値を書かない）
- `executed_by: playwright-test` を記録する（`playwright-mcp` と混同しない）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-110000/TC-SEC-020/` 配下に runner ログ・JUnit XML・レポート（storageState / トークンはマスク済み）を保存。SUT テストコード / config は変更しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 1 件・executed_by: playwright-test・認証済み/未認証の挙動差〔全 pass〕を actual に記録・機微情報マスク値のみ）を 1 コードブロックで返却 |
| 終了状態 | scope 全 1 件（TC-SEC-020）を 1 エントリで pass 返却 |

## 関連ケース

- case-02: 未認証アクセス制御 pass（MCP 経路・`automation: playwright`）との経路差分
- case-04: 機微情報マスキング（MCP 経路）と、playwright-test 経路での storageState マスキングの対比
- case-12: Playwright/ランナー・fixtures（認証フィクスチャ）/SUT テストコード不在による skipped（playwright-test 実走前提の欠如）との対比
- case-05: MCP 未ロードによる skipped（MCP 経路の実行手段不在）との前提差分
