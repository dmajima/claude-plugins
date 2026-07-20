# case-09 automation: playwright-test 実走 pass（npx playwright test で .spec.ts を実行し全 pass を記録）

`automation: playwright-test` の functional ケースについて、fixtures.yaml + SUT テストコードを前提に `npx playwright test`（Bash 実行）で .spec.ts を実走し、対象テストが**全 pass** することを JUnit / レポートからエビデンス化して `executed_by: playwright-test` で記録することを検証する。既存の MCP（`automation: playwright`）経路と併存し、置き換えないことを確認する。実行手段不在時の skipped は case-10 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-web` / `run_id=R20260719-101500` / 対象ケース `TC-FUNC-020`（`automation: playwright-test`・`fixtures: [authenticatedPage]`・priority: high）/ 対象 URL |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | `fixtures.yaml`（`{base}/{target-slug}/fixtures.yaml`）と SUT テストコード（`test_root` 配下の `.spec.ts` / `playwright.config.ts` / フィクスチャ）が test-fixture により生成済み。`npx playwright test` が実行可能で、対象 spec は全 pass する（欠陥なし） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: fixtures.yaml と SUT テストコードを前提に `npx playwright test` で実走し `executed_by: playwright-test` で記録）、SKILL.md「実行フロー」の playwright-test 実走経路、`${CLAUDE_SKILL_DIR}/references/functional-execution.md` 7 章（前提・実行 Bash・結果マッピング〔7.3: 全 pass → pass〕とエビデンス化）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 2 章（`npx playwright test` 実行規約）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by: playwright-test）・7 章（テストランナー実行時のエビデンス）。

## 期待動作

- ケースの `automation: playwright-test` を検出し、MCP のその場操作ではなく `npx playwright test`（Bash）で対象 `.spec.ts` を実走する（`--project` / spec パス指定）
- SUT テストコード・`playwright.config.ts` を**生成・改変しない**（実走のみ。生成は test-fixture の責務）
- 対象テストが全 pass するため status を **pass** とする（fail 含む → fail / 設定エラーでテスト未実行 → blocked の status マッピングは functional-execution.md 7.3 を正とするが、本ケースは全 pass の主系）
- エビデンス（stdout / stderr ログ・JUnit XML・HTML レポート）を `evidence/R20260719-101500/TC-FUNC-020/` へ保存する（命名例: `80_playwright-stdout.txt` / `81_junit.xml`）
- `executed_by: playwright-test` を記録する（`playwright-mcp` と混同しない）。`duration_sec` は runner の実行時間
- 既存の MCP・manual-assist 経路には影響しない（併存）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-101500/TC-FUNC-020/` 配下に runner ログ・JUnit XML・レポートを保存。SUT テストコード / config は変更しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件・executed_by: playwright-test・全 pass を actual に記録）を 1 コードブロックで返却。「引き渡し（中間結果 JSON 返却）」に準拠 |
| 終了状態 | scope 全 1 件（TC-FUNC-020）を 1 エントリで pass 返却 |

## 関連ケース

- case-01: Playwright MCP 経路（`automation: playwright`）の pass（executed_by: playwright-mcp）との対比
- case-02: 表示不一致 fail（MCP 経路の fail 側の分岐。playwright-test 経路でも fail は functional-execution.md 7.3 の status マッピングに従う）
- case-10: Playwright/ランナー・fixtures/SUT テストコード不在による skipped（playwright-test 実走前提の欠如）との対比
- case-07: manual-assist × 対話（executed_by: human-assisted）との経路差分
