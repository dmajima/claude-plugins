# case-10 automation: playwright-test 実走 pass（npx playwright test で IT-b をモックフィクスチャ実走し全 pass を記録）

`automation: playwright-test` の結合ケースについて、fixtures.yaml + SUT テストコードを前提に `npx playwright test`（Bash 実行）で .spec.ts を実走し、IT-b の外部依存を fixtures.yaml のモックフィクスチャ（route.fulfill）で差し替えて実接続なしに再現可能な検証を行い、対象テストが**全 pass** することを JUnit / レポートからエビデンス化して `executed_by: playwright-test` で記録することを検証する。既存の MCP・API 補助確認・manual-assist 経路と併存し置き換えないことを確認する。実行手段不在時の skipped は case-11 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-103000` / 対象ケース `TC-ITB-020`（`automation: playwright-test`・`fixtures: [mockPaymentApi]`。決済 API 連携を成功/失敗で切替検証）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | `fixtures.yaml`（`type: mock` の `mockPaymentApi` を含む）と SUT テストコード（`.spec.ts` / `playwright.config.ts` / フィクスチャ）が test-fixture により生成済み。`npx playwright test` が実行可能で、対象 spec は全 pass する（欠陥なし） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: fixtures.yaml のモックフィクスチャで外部依存を差し替え `npx playwright test` で実走・`executed_by: playwright-test`）、SKILL.md「実行フロー」の playwright-test 実走経路、`${CLAUDE_SKILL_DIR}/references/integration-execution.md` 8 章（前提・IT-a / IT-b の再現可能実走・結果マッピング〔8.3: 全 pass → pass〕とエビデンス化）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 2〜3 章（実行規約・モック route.fulfill）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by: playwright-test）・7 章（テストランナー実行時のエビデンス）。

## 期待動作

- ケースの `automation: playwright-test` を検出し、`npx playwright test`（Bash）で対象 `.spec.ts` を実走する（`--project` / spec パス指定）
- IT-b の外部依存（決済 API）を fixtures.yaml のモックフィクスチャ（route.fulfill）で差し替え、成功 / 失敗応答を切り替えて自システムのエラーハンドリングを検証する（実外部接続は行わない）
- モック実行のケースは actual に「モック応答・実接続未検証」を明記する。実疎通・契約整合そのものが目的のケースはモック pass で代替せず skipped + reason とする（本ケースはエラーハンドリング検証が目的でありモック実走が妥当）
- SUT テストコード・`playwright.config.ts` を生成・改変しない（実走のみ。生成は test-fixture の責務）
- 対象テストが全 pass するため status を **pass** とする（fail 含む → fail〔JUnit・トレースから defect 3 点セット〕/ 設定エラーで未実行 → blocked の status マッピングは integration-execution.md 8.3 を正とするが、本ケースは全 pass の主系）
- エビデンス（stdout / stderr ログ・JUnit XML・HTML レポート）を `evidence/R20260719-103000/TC-ITB-020/` へ保存し、API レスポンスをログに含む場合は保存前にマスクする
- `executed_by: playwright-test` を記録する（`playwright-mcp` / `api` と混同しない）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-103000/TC-ITB-020/` 配下に runner ログ・JUnit XML・レポート（API ログはマスク済み）を保存。SUT テストコード / config は変更しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-integration" / 受領 run_id / results 1 件・executed_by: playwright-test・モック利用と実接続未検証・全 pass を actual に明記）を 1 コードブロックで返却 |
| 終了状態 | scope 全 1 件（TC-ITB-020）を 1 エントリで pass 返却 |

## 関連ケース

- case-01: IT-a MCP 経路（`automation: playwright`）の pass との対比
- case-02: IT-b 外部接続不可 → スタブポリシー判断（MCP 経路のスタブ運用）との対比（playwright-test 経路ではモックフィクスチャが役割を担う）
- case-03: IT-b fail（MCP 経路の fail 側。playwright-test 経路でも fail は integration-execution.md 8.3 の status マッピングに従う）
- case-11: Playwright/ランナー・fixtures/SUT テストコード不在による skipped（playwright-test 実走前提の欠如）との対比
- case-08: manual-assist × 対話（executed_by: human-assisted）との経路差分
