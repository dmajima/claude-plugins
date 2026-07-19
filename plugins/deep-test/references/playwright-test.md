<!-- PLAYWRIGHT-TEST-SENTINEL-v1 -->
# Playwright Test 実行規約・fixtures.yaml スキーマ（playwright-test）

`deep-test` プラグインの **再現可能テスト経路**（Playwright Test = `.spec.ts` + フィクスチャ）に関する規範 SSOT。
test-fixture（Phase 1.6）が生成する `fixtures.yaml` の完全スキーマ、Playwright Test の実行規約（`npx playwright test` / projects / storageState / `test.extend`）、
および 認証(storageState) / モック(route.fulfill) / シード / base(test.extend) のパターン規範を定義する唯一の場所である。
フィールド・enum 値の追加・変更・改廃は本ファイルを起点に行い、他 references・スキルへは参照のみで内容を複製しない。

---

## 0. 2 モードの棲み分け（探索的 MCP と再現可能 Playwright Test）

deep-test の Playwright 利用には 2 モードがあり、正本ファイルを分けて管理する。両者は排他ではなく補完関係である。

| モード | 正本 | 実体 | automation / executed_by | 主用途 |
|-------|------|------|--------------------------|--------|
| 探索的（その場操作） | `playwright-mcp.md` | Playwright MCP ツール（`mcp__playwright__*`） | `playwright` / `playwright-mcp` | 手順を対話的に実行しながら確認する探索的テスト |
| 再現可能（コード化） | 本ファイル（`playwright-test.md`） | `.spec.ts` + フィクスチャ + `playwright.config.ts` | `playwright-test` / `playwright-test` | fixture 基盤に載せた反復実行可能な自動テスト |

- 既存の探索的 MCP フロー（`automation: playwright`）は **不変**。`playwright-test` は fixture 基盤があるケースの **オプトイン経路** であり、既定の探索的フローを崩さない
- 探索的モードの MCP 登録・既存登録検出・正本ツールリスト・再起動制約は `playwright-mcp.md` を参照する（本ファイルは重複定義しない）
- automation / executed_by の enum 定義は `yaml-schema-cases.md`（automation）・`yaml-schema-results.md`（executed_by）が SSOT。本ファイルは棲み分けの相互参照のみ行う

---

## 1. fixtures.yaml スキーマ（SSOT）

`fixtures.yaml` は test-fixture（Phase 1.6）が生成し、`test-design`（Phase 2）が **単方向に消費** する機械可読のフィクスチャマニフェストである。
配置は `{base}/{target-slug}/fixtures.yaml`（`data-locations.md` の配置規約に準拠）。生成主体は test-fixture の LLM（Write で直接生成）である。

### 1.1 meta

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `target` | string | 必須 | 対象名（`analysis.yaml` の `meta` および `test-cases.yaml` の `meta.target` と整合させる） |
| `target_slug` | string | 必須 | 解決済み target-slug（解決フローは `data-locations.md`） |
| `created_at` | string（ISO8601） | 必須 | ファイル作成日時 |
| `updated_at` | string（ISO8601） | 必須 | ファイル最終更新日時（拡充のたびに更新する） |
| `schema_version` | integer | 必須 | スキーマ版数。現行 `1`。非互換変更時は本ファイルの改訂とセットでインクリメントする |
| `analysis_consumed` | boolean | 必須 | `analysis.yaml` を材料にしたか。`false` は analysis.yaml 非存在時の軽量補完（推定を確定情報として書かない・各 fixture の `confidence` を下げる） |
| `test_root` | string | 必須 | SUT 内のテストコード基準ディレクトリ（`project=` からの相対。例: `"tests"`） |
| `config_artifact` | string または `null` | 必須（null 許容） | 生成 / 拡充した `playwright.config.ts` の相対パス。生成しなかった場合は `null` |

### 1.2 fixtures[]

| フィールド | 型 / 許容値 | 必須 | 説明 |
|-----------|------------|------|------|
| `name` | string | 必須 | フィクスチャ名。`test-cases.yaml` の `cases[].fixtures` から参照される識別子（マニフェスト内で一意） |
| `type` | enum `auth` / `mock` / `seed` / `base` | 必須 | フィクスチャ種別（1.3 の許容値表） |
| `provides` | string | 必須 | 提供内容（何を用意するフィクスチャか。自然文） |
| `artifact` | string | 必須 | 生成 / 拡充したコードファイルの SUT 内相対パス（例: `"tests/fixtures/auth.fixture.ts"`） |
| `usage` | string | 任意 | 使用例（テスト内での参照方法。コロン・バッククォートを含むため 1.4 のクォート規約に従う） |
| `depends_on` | list[string] | 任意 | 依存する他フィクスチャの `name`（例: 認証済み page が storageState フィクスチャに依存する） |
| `source_refs` | list[string] | 任意 | 消費した `analysis.yaml` の `entry_points` / `external_dependencies` の ID（トレーサビリティ。捏造しない） |
| `status` | enum `created` / `extended` / `existing` | 必須 | 拡充責務のトレース（1.3 の許容値表） |
| `confidence` | enum `high` / `medium` / `low` | 必須 | 本フィクスチャ設計の確信度（縮退・補完時は下げる） |

### 1.3 enum 許容値

| フィールド | 値 | 意味 |
|-----------|-----|------|
| `type` | `auth` | 認証フィクスチャ（`auth.setup.ts` + storageState の再利用） |
| `type` | `mock` | モックフィクスチャ（外部依存を `route.fulfill` / network interception で差し替え） |
| `type` | `seed` | シードデータ（前提データの投入・クリーンアップ。`globalSetup` / seed スクリプト） |
| `type` | `base` | ベースフィクスチャ（`test.extend()` によるカスタムフィクスチャ: 認証済み page・モック済み context 等） |
| `status` | `created` | 今回新規作成した |
| `status` | `extended` | 既存基盤に不足分を追加した（非破壊マージ） |
| `status` | `existing` | 既存を検出したのみ（本 run では変更していない） |
| `confidence` | `high` / `medium` / `low` | 設計の確からしさ。`analysis_consumed: false` や縮退時は下げる |

### 1.4 YAML 記法の遵守（実体化時の必須事項）

`fixtures.yaml` は `test-design` が機械可読で消費する SSOT であり、実体化した結果は **必ず妥当な（parse 可能な）YAML** でなければならない（`yaml-schema-analysis.md` 2.1 と同一規約）。

- 自由記述の文字列値（`provides` / `usage` 等）で `:`（コロン）・`` ` ``（バッククォート）・`<` `>` `#` `[` `]` `{` `}` を含む、または先頭が `-` / `?` / `@` 等で始まるものは **ダブルクォートで囲む**（`usage` はコード断片を含むため原則クォートする）
- 未クォートのバッククォートや `key: ` と誤認される `:` は ScannerError を招くため許容しない

### 1.5 記入例

```yaml
meta:
  target: sample-web-app
  target_slug: sample-web-app
  created_at: "2026-07-17T10:00:00+09:00"
  updated_at: "2026-07-17T10:00:00+09:00"
  schema_version: 1
  analysis_consumed: true            # analysis.yaml を材料にした（false は軽量補完）
  test_root: "tests"                 # project= からの相対
  config_artifact: "playwright.config.ts"
fixtures:
  - name: authenticatedPage
    type: auth                       # auth | mock | seed | base
    provides: "ログイン済みの page（storageState 経由）"
    artifact: "tests/fixtures/auth.fixture.ts"
    usage: "test('...', async ({ authenticatedPage }) => { ... })"
    depends_on: [adminStorageState]
    source_refs: [EP-001]            # 消費した analysis.yaml の EP / EXT ID（任意）
    status: created                  # created | extended | existing
    confidence: high                 # high | medium | low
  - name: mockPaymentApi
    type: mock
    provides: "決済 API を成功 / 失敗で差し替える"
    artifact: "tests/fixtures/payment.fixture.ts"
    source_refs: [EXT-payment-api]
    status: created
    confidence: medium
  - name: seedOrders
    type: seed
    provides: "注文テストデータ 10 件を投入・クリーンアップする"
    artifact: "tests/seed/orders.seed.ts"
    status: created
    confidence: medium
```

- `test-design` は各ケースの `cases[].fixtures` フィールドで `fixtures[].name` を参照し、当該ケースの `automation` に `playwright-test` を選ぶ（`yaml-schema-cases.md`）

---

## 2. Playwright Test 実行規約（.spec.ts + フィクスチャ）

`automation: playwright-test` のケースは、Playwright MCP のその場操作ではなく、`.spec.ts` テストファイルと `playwright.config.ts` を **Playwright Test ランナーで実行** する経路を前提とする。

| 項目 | 規範 |
|------|------|
| 実行コマンド | `npx playwright test`（プロジェクト絞り込みは `--project`、単一ファイルは末尾にパス指定） |
| 設定ファイル | `playwright.config.ts` に `testDir` / `use.baseURL` / `use.ignoreHTTPSErrors` / `projects` を定義する |
| 認証の再利用 | `projects` に setup プロジェクト（`auth.setup.ts`）と本体プロジェクトを分け、本体側 `use.storageState` で保存済みログイン状態を再利用する |
| カスタムフィクスチャ | `test.extend()` で認証済み page・モック済み context・シード済みデータ等をフィクスチャ化し、テスト側は分割代入で受け取る |
| 証明書 | ローカル自己署名証明書は `use.ignoreHTTPSErrors: true` で無視する（`playwright-mcp.md` の `--ignore-https-errors` と同趣旨） |
| ヘッドレス | CI / 自動実行はヘッドレスを既定とする |

> 実行機構の位置付け: `playwright-test` ケースの実走経路（`npx playwright test`）は functional / integration / scenario / security の 4 実行スキルに **実装済み**（各 SKILL.md + `references/*-execution.md` の該当章）。`fixtures.yaml` / SUT テストコードが未整備、またはテストランナー未導入時は実行を偽装せず `skipped` + reason で返す（SKIPPED 規範は `execution-policy.md`）。unit / performance は playwright-test 実走の **対象外**。test-fixture は fixtures.yaml と SUT テストコードの **生成** に徹し、実走は上記 4 実行スキルが担う。

### 2.1 playwright.config.ts の骨子（例）

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: process.env.BASE_URL ?? 'https://localhost:5001',
    ignoreHTTPSErrors: true,
  },
  projects: [
    { name: 'setup', testMatch: /auth\.setup\.ts/ },
    {
      name: 'authenticated',
      dependencies: ['setup'],
      use: { storageState: 'tests/.auth/user.json' },
    },
  ],
});
```

---

## 3. フィクスチャパターン規範

各 `type` のフィクスチャは以下の規範に従って生成 / 拡充する。既存基盤がある場合は破壊的上書きを避け、不足分を非破壊で追加する。

### 3.1 認証（auth / storageState）

- `auth.setup.ts` で 1 度だけログインし、`context.storageState({ path })` で storageState を保存する。本体プロジェクトは `use.storageState` でこれを再利用し、各テストで再ログインしない
- ロール別（admin / general 等）に storageState を分割する場合は、`analysis.yaml` の `entry_points[].auth` / `attack_surface_summary` を材料にロールを決める
- storageState 出力先（例: `tests/.auth/*.json`）は **セッショントークンを含むため .gitignore 前提**。test-fixture は `.gitignore` への追記を提案し、実トークンをコミットしない
- 認証情報の実値を `config` / `fixture` / `setup` に **ハードコードしない**。環境変数・credentials-manager 経由の取得コードとして記述する（4 章）

### 3.2 モック（mock / route.fulfill）

- 外部 API・決済・メール・キュー等を `page.route()` / `context.route()` + `route.fulfill()` で差し替える `test.extend` を生成する
- モック対象は `analysis.yaml` の `dependency_summary.external_dependencies[]`（`kind: http | thirdparty` 等）から選定し、`source_refs` に対応 ID を記録する
- 成功 / 失敗 / タイムアウト等の応答バリエーションを差し替え可能な形にする（外部異常時の自システム挙動を検証可能にする）

### 3.3 シード（seed / globalSetup）

- テスト前提データの投入・クリーンアップを `globalSetup` / seed スクリプト / seed フィクスチャで用意する
- 投入したデータは必ずクリーンアップ手順（テスト後の削除・状態復元）とセットで設計し、共有環境の状態汚染を防ぐ（テストデータ分離の趣旨は `execution-policy.md`）
- 破壊的操作（既存データの削除・更新）を含む seed は、その旨をフィクスチャの `provides` に明示する

### 3.4 ベース（base / test.extend）

- `test.extend()` により、認証済み page・モック済み context・page object 等を合成したカスタムフィクスチャを提供する
- 上位フィクスチャ（auth / mock / seed）に依存する場合は `depends_on` に依存先 `name` を記録し、責務（認証 / モック / シード）を分離したまま合成する
- テスト側は `test('...', async ({ authenticatedPage }) => { ... })` の形でフィクスチャを分割代入で受け取る

---

## 4. 書き込み境界・認証情報

test-fixture は deep-test で **初めて SUT にファイルを書き込むスキル** である。生成 / 拡充の対象は以下に限る。

| 対象 | 操作 | 境界 |
|------|------|------|
| SUT の **テストディレクトリ**（`{project}/{test_root}/` 配下・`playwright.config.ts`） | Write / Edit 可 | フィクスチャ・setup・シード・config の生成 / 拡充に限る |
| SUT の **プロダクションコード**（アプリ本体のソース・DB スキーマ・業務ロジック） | 不可 | 一切変更しない（プロダクションコード不変原則） |
| SUT の `.gitignore` | 追記の提案のみ（storageState / `.auth` の除外） | 実トークンのコミット防止（対話確認 or 提案に留める） |
| deep-test データ領域 `{base}/{target-slug}/fixtures.yaml` | Write 可 | マニフェストの生成 / 更新 |
| `test-results.yaml` / `test-cases.yaml` / `analysis.yaml` | 不可 | 各所有スキルの専有 |

- 認証情報の実値を config / fixture / setup に **ハードコードしない**（環境変数・credentials-manager 経由の取得コードとして記述する）。機微情報の取り扱い・マスキングは `evidence-policy.md` に従う
- 既存テストコードの拡充時は破壊的上書きを避け、既存の書式・命名を尊重して不足分のみ非破壊マージする

---

## 5. 関連 references

| 参照先 | 内容 |
|-------|------|
| `playwright-mcp.md` | 探索的モード（MCP）の正本。登録・既存登録検出・正本ツールリスト・再起動制約 |
| `yaml-schema-analysis.md` | test-fixture が材料に消費する `analysis.yaml` の完全スキーマ（entry_points / external_dependencies / attack_surface_summary） |
| `yaml-schema-cases.md` | `automation: playwright-test` / `cases[].fixtures`（fixtures.yaml の name 参照）の定義 |
| `yaml-schema-results.md` | `executed_by: playwright-test` の定義 |
| `execution-policy.md` | playwright-test の実行 / SKIPPED 規範（ランナー未導入時は skipped + reason） |
| `data-locations.md` | `fixtures.yaml` の配置パス・target-slug 解決・SUT テストコードは deep-test 管理外である旨 |
| `evidence-policy.md` | 認証情報・機微情報のマスキング方針 |
