# case-02 既存基盤の拡充（非破壊マージ・不足分のみ追加・既存の書式/命名を尊重）

SUT に既に Playwright 基盤（`playwright.config.ts` / 一部 fixtures）が存在するケース。既存を壊さず不足分（未カバーの認証パターン・未モックの外部依存）のみを非破壊で追加し、`status` で created / extended / existing を区別することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web project=./ base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6） |
| 前提 | `analysis.yaml` 存在（web-app・認証 EP に admin/general 2 ロール・外部依存にメール送信 API）/ SUT に既存 `playwright.config.ts` と `tests/fixtures/auth.fixture.ts`（general ロールのみ）が存在。メール API のモックは未整備 |

## 分岐の根拠

SKILL.md「実行フロー」4〜6（既存検出＝有 → 拡充）・「重要な制約」（既存の書式・命名を尊重し破壊的上書きを避ける・不足分の非破壊マージ）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 5 章（既存基盤の検出）・6 章（拡充＝不足分のみ非破壊追加・status: extended/existing）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 3 章（既存基盤がある場合は破壊的上書きを避け不足分を非破壊で追加）・4 章（書き込み境界）、`${CLAUDE_SKILL_DIR}/references/fixture-patterns.md` 1.1 章（ロール別 storageState 分割）・2 章（route.fulfill モック）。

## 期待動作

- `analysis.yaml` を消費し、認証 EP の admin/general 2 ロールと外部依存（メール API）を材料化する
- `project=` 起点で既存 `playwright.config.ts` と `tests/fixtures/auth.fixture.ts` を Glob/Grep で検出する。既存フィクスチャの `name`・提供内容を把握し、重複生成を避ける
- 不足分のみを非破壊で追加する: admin ロールの storageState（`tests/.auth/admin.json` と対応する setup / config projects 追記）・メール API のモックフィクスチャ（`tests/fixtures/mail.fixture.ts`）
- 既存の `general` ロール fixture・既存 config の書式・命名を**破壊的に上書きしない**（既存の記法を尊重して不足分を追記・新規ファイル追加する）
- `fixtures.yaml` に既存検出分を `status: existing`、今回追加分を `status: extended` として記録し、`meta.updated_at` を更新する
- 認証情報は環境変数経由・`tests/.auth/` の `.gitignore` 追記を提案する
- `deep-test:fixture-architect` を単独起動し、拡充の非破壊性・status の実態一致・責務分離をレビューさせ、重大指摘を反映してから返却する
- test-results.yaml / test-cases.yaml / analysis.yaml・SUT のプロダクションコードへは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 追加分の SUT テストコード（`tests/fixtures/mail.fixture.ts`・admin ロールの setup / config 追記）・更新された `{base}/{target-slug}/fixtures.yaml`（既存分 status: existing・追加分 status: extended・updated_at 更新）。既存 fixture の破壊的上書きなし。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | フィクスチャ構築結果サマリ（判定=拡充・type 別件数と status 内訳〔existing / extended〕・追加した相対パス・fixture-architect 所見〔非破壊性の確認〕・.gitignore 追記提案） |
| 終了状態 | 既存を尊重した非破壊拡充後に fixtures.yaml を更新して委譲元へ返却。決定は行わず次フェーズ（test-design）へ |

## 関連ケース

- case-01: 既存基盤なしでの新規生成（本ケースの対＝status: created）
- case-06: 書き込み境界の遵守（拡充時のプロダクションコード不変・非破壊も本ケースで確認）
- case-04: 非対話・委譲での自動進行
