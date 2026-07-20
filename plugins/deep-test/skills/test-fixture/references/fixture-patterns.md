<!-- TEST-FIXTURE-PATTERNS-SENTINEL-v1 -->
# test-fixture パターン集（認証 / モック / シード / base）

`test-fixture` が生成 / 拡充するフィクスチャの実装パターンと最小コード例。SKILL.md・`fixture-procedures.md` 6 章から参照される。
実行規約・fixtures.yaml スキーマ・書き込み境界の SSOT は `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` であり、本書はその**パターン別の適用例**を補完する（`playwright.config.ts` の骨子は playwright-test.md 2.1 を正とし、本書は fixture コード側を主に示す。規範本文は複製しない）。

- 各コード例は**最小の骨子**であり、対象の技術スタック（`analysis.yaml` の `architecture.frameworks`）に合わせて調整する
- 認証情報の実値は**ハードコードしない**（環境変数・credentials-manager 経由）。storageState 出力先は `.gitignore` 追記を提案する
- 既存基盤の拡充時は既存の書式・命名を尊重し、不足分のみ非破壊で追加する
- 生成した各フィクスチャは `fixtures.yaml` の 1 エントリ（`type` / `name` / `provides` / `artifact` / `status` / `confidence`）として記録する

---

## 1. 認証（type: auth / storageState）

`analysis.yaml` の `entry_points[].auth`・`attack_surface_summary` を材料に、ログインを 1 度だけ実行して storageState を保存し、本体プロジェクトで再利用する。各テストで再ログインしない。

### 1.1 auth.setup.ts（ログイン → storageState 保存）

```ts
// tests/auth.setup.ts
import { test as setup, expect } from '@playwright/test';

const authFile = 'tests/.auth/user.json';

setup('authenticate', async ({ page }) => {
  // 認証情報の実値はハードコードせず環境変数から取得する（credentials-manager 経由で注入）
  const user = process.env.E2E_USER;
  const pass = process.env.E2E_PASS;
  if (!user || !pass) throw new Error('E2E_USER / E2E_PASS が未設定です');

  await page.goto('/login');
  await page.getByLabel('ユーザー名').fill(user);
  await page.getByLabel('パスワード').fill(pass);
  await page.getByRole('button', { name: 'ログイン' }).click();
  await expect(page).toHaveURL(/dashboard/);

  await page.context().storageState({ path: authFile });
});
```

- `playwright.config.ts` の `projects` で setup プロジェクトと本体プロジェクトを分け、本体側 `use.storageState: 'tests/.auth/user.json'` で再利用する（骨子は playwright-test.md 2.1）
- ロール別（admin / general 等）に storageState を分割する場合は、`entry_points[].auth` / `attack_surface_summary` からロールを決め、`tests/.auth/admin.json` 等に分ける
- storageState 出力先（`tests/.auth/*.json`）は**セッショントークンを含むため `.gitignore` 前提**。`tests/.auth/` の追記を提案する

## 2. モック（type: mock / route.fulfill）

`analysis.yaml` の `dependency_summary.external_dependencies[]`（`kind: http | thirdparty` 等）を材料に、外部 API・決済・メール・キューを `route.fulfill` で差し替える `test.extend` を生成する。

### 2.1 payment.fixture.ts（外部 API を成功 / 失敗で差し替え）

```ts
// tests/fixtures/payment.fixture.ts
import { test as base } from '@playwright/test';

type PaymentFixtures = {
  mockPaymentApi: (outcome: 'success' | 'failure') => Promise<void>;
};

export const test = base.extend<PaymentFixtures>({
  mockPaymentApi: async ({ context }, use) => {
    await use(async (outcome) => {
      await context.route('**/api/payment', async (route) => {
        // 成功 / 失敗 / タイムアウト等の応答バリエーションを差し替え可能にする
        await route.fulfill({
          status: outcome === 'success' ? 200 : 502,
          contentType: 'application/json',
          body: JSON.stringify({ result: outcome }),
        });
      });
    });
  },
});
```

- モック対象は外部依存 ID（`source_refs` に `EXT-...` を記録）で選定する
- 成功だけでなく失敗・タイムアウトを差し替えられる形にし、外部異常時の自システム挙動を検証可能にする
- `context.route` は同一 context 内の全 page に適用、`page.route` は単一 page に適用。用途に応じて選ぶ

## 3. シード（type: seed / globalSetup）

テスト前提データの投入・クリーンアップを `globalSetup` / seed スクリプト / seed フィクスチャで用意する。投入とクリーンアップは必ずセットで設計し、共有環境の状態汚染を防ぐ。

### 3.1 orders.seed.ts（前提データ投入・クリーンアップ）

```ts
// tests/seed/orders.seed.ts
import { test as base } from '@playwright/test';

type SeedFixtures = { seedOrders: string[] };

export const test = base.extend<SeedFixtures>({
  seedOrders: async ({ request }, use) => {
    // 投入（実 API / シード用エンドポイント経由。認証情報はハードコードしない）
    const created: string[] = [];
    for (let i = 0; i < 10; i++) {
      const res = await request.post('/api/test/orders', { data: { seq: i } });
      created.push((await res.json()).id);
    }
    await use(created);
    // クリーンアップ（テスト後に必ず削除・状態復元）
    for (const id of created) {
      await request.delete(`/api/test/orders/${id}`);
    }
  },
});
```

- 破壊的操作（既存データの削除・更新）を含む seed は、その旨を fixtures.yaml の `provides` に明示する
- リポジトリ全体で 1 度だけ投入したい場合は `globalSetup`（config の `globalSetup` / `globalTeardown`）を用いる

## 4. ベース（type: base / test.extend）

`test.extend()` により、認証済み page・モック済み context・page object 等を合成したカスタムフィクスチャを提供する。上位（auth / mock / seed）に依存する場合は `depends_on` に依存先 `name` を記録し、責務を分離したまま合成する。

### 4.1 auth.fixture.ts（認証済み page を提供する base フィクスチャ）

```ts
// tests/fixtures/auth.fixture.ts
import { test as base } from '@playwright/test';

type AuthFixtures = { authenticatedPage: import('@playwright/test').Page };

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    // storageState は playwright.config.ts の projects.use.storageState で注入済み。
    // ここでは共通の前処理（ダッシュボード遷移等）を施した page を提供する。
    await page.goto('/dashboard');
    await use(page);
  },
});
```

- テスト側は `test('...', async ({ authenticatedPage }) => { ... })` の形で分割代入で受け取る
- 複数のフィクスチャ（認証 + モック等）を 1 つの base に合成する場合は、`mergeTests`（`@playwright/test`）で複数の `test.extend` を結合し、責務分離を保つ

## 5. .gitignore への追記提案

storageState・認証状態ファイルは実トークンを含むため、以下の追記を**提案**する（実追記は対話確認 or 提案に留める）。

```gitignore
# Playwright 認証状態（実トークンを含むためコミットしない）
tests/.auth/
```

- 機微情報の取り扱い・マスキングは `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` に従う

---

## 6. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` | fixtures.yaml スキーマ・playwright.config.ts 骨子・実行規約・パターン規範・書き込み境界の SSOT |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` | 材料 `analysis.yaml`（entry_points / external_dependencies / attack_surface_summary） |
| `${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` | 消費 → 検出 → 生成/拡充 → 出力 → 自己チェックの手順 |
