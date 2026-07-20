# case-01 web-app 新規基盤生成（既存基盤なし・analysis.yaml 消費 → 認証/モック/シード/base 生成 → fixture-architect 自己チェック）

既存の Playwright 基盤が無い web-app に対し、`analysis.yaml` を材料にフィクスチャ基盤を新規生成するケース。消費 → 既存検出（無）→ 生成 → `fixtures.yaml` 出力 → `fixture-architect` 自己チェック → 返却の一連の流れを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「この web アプリのフィクスチャ基盤を作って。カレントが SUT のリポジトリルート」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | `{base}/{target-slug}/analysis.yaml` が存在（target_type=web-app・認証 EP あり〔session〕・外部依存に決済 API）/ SUT に `playwright.config.ts` / `{tests}/fixtures/` は未存在 / `--non-interactive` なし |

## 分岐の根拠

SKILL.md「実行フロー」1〜7 および「実行モード判定」（対話）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（入力解決）・3.1 章（analysis.yaml 消費）・4 章（要否判定＝有効）・5 章（既存検出＝無）・6 章（新規作成）・7 章（fixtures.yaml 出力）・8 章（自己チェック）、`${CLAUDE_SKILL_DIR}/references/fixture-patterns.md` 1〜4 章（認証/モック/シード/base の生成）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 1〜4 章（fixtures.yaml スキーマ・実行規約・書き込み境界）、同 `data-locations.md` 1 章（基準ディレクトリ）・4 章（新規 slug 解決）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- target-slug を data-locations.md 4 章で解決し、`{base}/{target-slug}/analysis.yaml` を Read で消費する（`entry_points.auth`=session → 認証、`external_dependencies`=決済 API → モック、`attack_surface_summary` → 認証切替、`meta.target_type`=web-app → 要否判定）
- fixture 要否を「有効」と判定する（web-app・認証 EP / 外部依存あり）
- `project=`（カレント）起点で `playwright.config.ts` / `{tests}/fixtures/` / `auth.setup.ts` を Glob/Grep → 未存在 → 新規作成に分岐する
- `fixture-patterns.md` に従い、`auth.setup.ts`（ログイン → storageState 保存）・`playwright.config.ts`（projects で storageState 再利用）・`payment.fixture.ts`（route.fulfill で決済 API 差し替え）・`authenticatedPage` などの base フィクスチャ（test.extend）を生成する（すべて SUT のテストディレクトリのみ）
- 認証情報の実値をハードコードせず、環境変数（`process.env.E2E_USER` 等）から取得するコードにする。storageState 出力先（`tests/.auth/`）の `.gitignore` 追記を提案する
- `{base}/{target-slug}/fixtures.yaml`（playwright-test.md スキーマ・`meta.analysis_consumed: true`・各 fixture の `type` / `status: created` / `confidence`）を Write で生成する
- Agent ツールで `deep-test:fixture-architect` を **単独起動**する（プロンプトに解決済み絶対パスと agents.md 4.3 章の共通注入事項ブロックを含める。並列起動しない）
- fixture-architect の重大指摘（書き込み境界の逸脱・認証情報のハードコード等）を成果物へ反映してから返却する（エージェントに成果物を修正させない）
- test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | SUT テストコード（`playwright.config.ts`・`tests/auth.setup.ts`・`tests/fixtures/payment.fixture.ts`・`tests/fixtures/auth.fixture.ts` 等）・`{base}/{target-slug}/fixtures.yaml`（`analysis_consumed: true`・auth/mock/base の各 type・status: created）。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | SKILL.md「引き渡し」のフィクスチャ構築結果サマリ（対象種別・判定=生成・type 別件数と status 内訳・生成した SUT テストコードの相対パス・fixture-architect 所見・.gitignore 追記提案・「fixtures.yaml を材料に test-design が fixtures: と automation: playwright-test を決定する」） |
| 終了状態 | fixture-architect 自己チェック（重大指摘反映）後に fixtures.yaml + SUT テストコードを生成して返却。決定は行わず次フェーズ（test-design）へ |

## 関連ケース

- case-02: 既存基盤ありでの拡充（非破壊マージ）
- case-03: no-op（unit のみ・非 web＝生成しない）
- case-04: 非対話・委譲での自動進行
- case-05: analysis.yaml 欠落時の軽量補完（本ケースは消費あり）
- case-06: 書き込み境界・認証情報ハードコード回避（本ケースでも遵守するが主軸は case-06）
