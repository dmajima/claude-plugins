# case-10 automation: playwright-test 実行手段不在 → skipped（Playwright/ランナー・fixtures/SUT テストコード不在）

`automation: playwright-test` の system / uat シナリオケースだが、Playwright 本体・テストランナー（`npx playwright test`）が未導入、または `fixtures.yaml`（認証・シードフィクスチャ）/ SUT テストコードが不在で **実走前提が欠落** している場合に、実行を偽装せず当該ケースを `skipped` + reason で返すことを検証する。MCP 未ロードによる skipped（case-05）とは前提が異なり、こちらは **playwright-test 実走前提の欠如**（ランナー / fixtures / spec の不在）を扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-121000` / 対象ケース `TC-SYS-021`（`automation: playwright-test`・`fixtures: [authenticatedPage, seedOrders]`。受注→出荷の業務シナリオ）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 次のいずれかで playwright-test 実走前提が欠落: (a) Playwright 本体・`npx playwright test` が未導入、(b) `fixtures.yaml`（`{base}/{target-slug}/fixtures.yaml`・認証/シードフィクスチャを含む想定）が不在、(c) SUT テストコード（シナリオ `.spec.ts` / `playwright.config.ts`）が不在。Playwright MCP のロード状態は問わない（MCP 経路の話ではない） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: Playwright・ランナー未導入または fixtures.yaml 不在時は実行を偽装せず skipped + reason）、SKILL.md「重要な制約」（偽装禁止・導入を試みない）、`${CLAUDE_SKILL_DIR}/references/scenario-execution.md` 7.1（前提: 実走のみ・テストコードは生成しない）・7.4（SKIPPED 規範: 実行手段不在時は偽装せず skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（ランナー / fixtures 不在時 skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md`（実行規約）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 3 章（skipped の reason 必須）。

## 期待動作

- 実走前に前提（Playwright / ランナーの利用可否・`fixtures.yaml` の存在・SUT テストコードの存在）を確認し、欠落を検出する
- 欠落を検出したら `npx playwright test` を実行（実行を偽装）せず、当該ケースを **skipped** として返す
- reason に実際の欠落原因を記載する（例: 「Playwright / `npx playwright test` 未導入」「`fixtures.yaml`（認証 / シードフィクスチャ）不在」「SUT テストコード（シナリオ `.spec.ts` / `playwright.config.ts`）不在」）
- Playwright 本体・ランナー・fixtures・テストコードの**導入・生成を試みない**（環境構築は test-setup、テストコード生成は test-fixture の責務）
- skipped を「pass」「問題なし」「テスト成功」「受入完了」と書き換えない（未実施を問題なしと書かない）
- MCP 未ロード（case-05）とは別要因であることを reason で区別する（本ケースは MCP 経路ではなく playwright-test 実走前提の欠如）
- 長大シナリオの実行途中の中断（case-04）ではなく、実走前の前提欠如による未実施であることを reason で明確にする
- `executed_by` を `playwright-test` と偽装しない（実走していないため）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行手段不在のため実走せず、エビデンスは発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件が skipped + 欠落原因を記した reason）を 1 コードブロックで返却 |
| 終了状態 | scope 全 1 件（TC-SYS-021）を 1 エントリで skipped + reason 返却（偽装・pass への書き換えなし） |

## 関連ケース

- case-09: playwright-test 実走前提が揃った場合の pass（実行手段ありの主系）との対比
- case-05: MCP 未ロードによる skipped（MCP 経路の実行手段不在）との前提差分（本ケースは playwright-test 実走前提の欠如）
- case-04: 長大シナリオの実行途中の中断（未到達）と、実走前の前提欠如（本ケース）との区別
