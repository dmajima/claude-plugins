# case-12 automation: playwright-test 実行手段不在 → skipped（Playwright/ランナー・認証フィクスチャ/SUT テストコード不在）

`automation: playwright-test` の security ケースだが、Playwright 本体・テストランナー（`npx playwright test`）が未導入、または `fixtures.yaml`（認証フィクスチャ）/ SUT テストコードが不在で **実走前提が欠落** している場合に、実行を偽装せず当該ケースを `skipped` + reason で返すことを検証する。MCP 未ロードによる skipped（case-05）とは前提が異なり、こちらは **playwright-test 実走前提の欠如**（ランナー / 認証フィクスチャ / spec の不在）を扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-121500` / 対象ケース `TC-SEC-022`（`automation: playwright-test`・`fixtures: [authenticatedPage]`。保護リソースの未認証アクセス制御を認証済み/未認証で対検証）/ アプリ情報あり |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・非対話） |
| 前提 | 次のいずれかで playwright-test 実走前提が欠落: (a) Playwright 本体・`npx playwright test` が未導入、(b) `fixtures.yaml`（`{base}/{target-slug}/fixtures.yaml`・`type: auth` の認証フィクスチャ / storageState 保存 setup を含む想定）が不在、(c) SUT テストコード（`.spec.ts` / `playwright.config.ts`・認証済み/未認証プロジェクト）が不在。対象はテスト環境。Playwright MCP のロード状態は問わない（MCP 経路の話ではない） |

## 分岐の根拠

SKILL.md「実行モード判定」（`automation: playwright-test` のケース: Playwright・ランナー未導入または fixtures.yaml〔認証フィクスチャ〕不在時は実行を偽装せず skipped + reason）、SKILL.md「重要な制約」（偽装禁止・導入を試みない）、`${CLAUDE_SKILL_DIR}/references/security-execution.md` 7.1（前提: 実走のみ・テストコードは生成しない）・7.4（SKIPPED 規範: 実行手段不在時は偽装せず skipped + reason）・0 章（非破壊の操作境界は不変。本ケースは実走しないため観測も行わない）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章（ランナー / fixtures 不在時 skipped + reason）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 3.1（認証 storageState）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 3 章（skipped の reason 必須）。

## 期待動作

- 実走前に前提（Playwright / ランナーの利用可否・`fixtures.yaml`〔認証フィクスチャ〕の存在・SUT テストコードの存在）を確認し、欠落を検出する
- 欠落を検出したら `npx playwright test` を実行（実行を偽装）せず、当該ケースを **skipped** として返す
- reason に実際の欠落原因を記載する（例: 「Playwright / `npx playwright test` 未導入」「`fixtures.yaml`（認証フィクスチャ / storageState）不在」「SUT テストコード（`.spec.ts` / `playwright.config.ts`）不在」）
- Playwright 本体・ランナー・fixtures・テストコードの**導入・生成を試みない**（環境構築は test-setup、テストコード生成は test-fixture の責務）
- skipped を「pass」「問題なし」「テスト成功」と書き換えない（未実施を問題なしと書かない）。対象外領域を「問題なし」と結論しないのと同様、実行手段不在も「問題なし」としない
- MCP 未ロード（case-05）とは別要因であることを reason で区別する（本ケースは MCP 経路ではなく playwright-test 実走前提の欠如）
- 実走しないため保護リソースへのアクセス・機微情報の取得は発生しない（0 章の非破壊境界に抵触する操作を行わない）
- `executed_by` を `playwright-test` と偽装しない（実走していないため）
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行手段不在のため実走せず、エビデンス・機微情報は発生しない）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-security" / 受領 run_id / results 1 件が skipped + 欠落原因を記した reason）を 1 コードブロックで返却 |
| 終了状態 | scope 全 1 件（TC-SEC-022）を 1 エントリで skipped + reason 返却（偽装・pass への書き換えなし） |

## 関連ケース

- case-11: playwright-test 実走前提が揃った場合の pass（認証フィクスチャ storageState 切替の主系）との対比
- case-05: MCP 未ロードによる skipped（MCP 経路のブラウザ依存観点の実行手段不在。ヘッダ検査は curl 継続）との前提差分（本ケースは playwright-test 実走前提の欠如）
- case-06: 破壊的操作・対象外領域の拒否（別要因の未実施）との対比
