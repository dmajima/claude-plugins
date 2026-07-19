# case-09 automation: playwright-test 実走 pass（npx playwright test で system シナリオを実行し全 pass を記録）

`automation: playwright-test` の system / uat シナリオケースについて、fixtures.yaml（認証・シードフィクスチャ）+ SUT テストコードを前提に `npx playwright test`（Bash 実行）で業務シナリオ .spec.ts を再現可能に実走し、対象シナリオが**全 pass** することを JUnit / レポートからエビデンス化して `executed_by: playwright-test` で記録することを検証する。既存の MCP（`automation: playwright`）経路と併存し置き換えないことを確認する。実行手段不在時の skipped は case-10 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-104500` / 対象ケース `TC-SYS-020`（`automation: playwright-test`・`fixtures: [authenticatedPage, seedOrders]`。受注→出荷の業務シナリオ）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | `fixtures.yaml`（`type: auth` の `authenticatedPage`・`type: seed` の `seedOrders` を含む）と SUT テストコード（シナリオ `.spec.ts` / `playwright.config.ts` / フィクスチャ）が test-fixture により生成済み。`npx playwright test` が実行可能で、対象シナリオは全 pass する（欠陥なし） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: fixtures.yaml を前提に `npx playwright test` で system / uat シナリオを実走・`executed_by: playwright-test`）、SKILL.md「実行フロー」の playwright-test 実走経路の記述、`${CLAUDE_SKILL_DIR}/references/scenario-execution.md` 7 章（前提・実行 Bash とシナリオの再現・結果マッピング〔7.3: 全 pass → pass〕とエビデンス化）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 2〜3 章（実行規約・認証 storageState / シード）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by: playwright-test）・7 章（テストランナー実行時のエビデンス）。

## 期待動作

- ケースの `automation: playwright-test` を検出し、`npx playwright test`（Bash）で対象シナリオ `.spec.ts` を実走する（`--project` / spec パス指定）
- ログイン状態は認証フィクスチャ（storageState）で再利用し、前提データはシードフィクスチャ（seed）で再現する（毎回再ログイン・手動データ投入をしない）
- SUT テストコード・`playwright.config.ts` を生成・改変しない（実走のみ。生成は test-fixture の責務）
- 対象シナリオが全 pass するため status を **pass** とし、actual にシナリオ完遂を記録する（途中 fail → fail〔JUnit・トレースから到達ステップ・後続判断・defect 3 点セット〕/ 設定エラーで未実行 → blocked の status マッピングは scenario-execution.md 7.3 を正とするが、本ケースは全 pass の主系）
- 目視が要る UAT 観点は playwright-test 経路では機械判定できる範囲に限り、目視観点は MCP 経路 / manual-assist に委ねる旨を actual に明記する。UAT の pass を「受入完了」と結論しない
- エビデンス（stdout / stderr ログ・JUnit XML・HTML レポート）を `evidence/R20260719-104500/TC-SYS-020/` へ保存する
- `executed_by: playwright-test` を記録する（`playwright-mcp` と混同しない）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-104500/TC-SYS-020/` 配下に runner ログ・JUnit XML・レポートを保存。SUT テストコード / config は変更しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・executed_by: playwright-test・actual にシナリオ完遂状況〔全 pass〕）を 1 コードブロックで返却 |
| 終了状態 | scope 全 1 件（TC-SYS-020）を 1 エントリで pass 返却 |

## 関連ケース

- case-01: system シナリオ MCP 経路（`automation: playwright`）の pass との対比
- case-02: シナリオ途中 fail → 後続 blocked（MCP 経路）と、playwright-test 経路での途中 fail 記録（scenario-execution.md 7.3 の status マッピング）の対比
- case-10: Playwright/ランナー・fixtures/SUT テストコード不在による skipped（playwright-test 実走前提の欠如）との対比
- case-05: MCP 未ロードによる skipped（MCP 経路の実行手段不在）との前提差分
