# フロントエンドツールチェーン レビュー観点プロファイル

ビルド（Vite）・スタイリング（Tailwind / Sass / Bootstrap）・テスト（Vitest / Playwright / Jest）のツール群を横断的にレビューする際の観点。言語共通の観点は JavaScript / TypeScript / CSS の各言語プロファイルに従い、本ファイルは各ツール固有の追加観点のみを扱う。React / Vue 等の FW 観点は別プロファイルを参照する。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 対象と検出条件

差分・リポジトリに以下が含まれる場合、該当ツールの観点を適用する。

| ツール | 検出マーカー |
|--------|-------------|
| Vite | devDependencies に `vite`。`vite.config.ts` / `vite.config.js` |
| Tailwind CSS | dependencies/devDependencies に `tailwindcss`。v3: `tailwind.config.js` / v4: CSS 内の `@import "tailwindcss"` |
| Vitest | devDependencies に `vitest`。`vitest.config.ts` または `vite.config.ts` の `test` フィールド |
| Playwright | devDependencies に `@playwright/test`。`playwright.config.ts` |
| Jest | devDependencies に `jest`。`jest.config.js` / `jest.config.ts` / `package.json` の `jest` フィールド |
| Sass | devDependencies に `sass`。`.scss` / `.sass` ファイル |
| Bootstrap | dependencies に `bootstrap` |

Tailwind / Bootstrap は v3/v4・v4/v5 で設定方式が根本的に異なるため、**バージョンを先に確認**してから観点を適用する。

## 2. ツールごとのレビュー観点

### 2.1 Vite（ビルド）

- [ ] **秘匿値の `VITE_` 露出**: 秘密鍵・トークン・内部 API URL 等に `VITE_` プレフィクスを付けていないか（`VITE_` 付き変数はクライアントバンドルに埋め込まれ露出する） 【担当: security-engineer】
- [ ] **環境変数参照の一貫性**: クライアント公開値は `import.meta.env.VITE_XXX` で参照しているか。プレフィクスなし変数へのアクセスが `undefined` を招いていないか 【担当: implementation-engineer】
- [ ] **動的 import の適切さ**: コード分割の意図がある `import()` か。過剰・不要な動的 import でチャンクが細分化しすぎていないか 【担当: performance-reviewer】
- [ ] **ビルドターゲット**: `build.target` / ブラウザサポート範囲が要件と一致しているか（過度に新しい構文で対象ブラウザを壊していないか） 【担当: implementation-engineer】

### 2.2 Tailwind CSS（スタイリング）

- [ ] **動的クラス組み立て**: `text-${color}-500` のような文字列補間でクラスを生成していないか（コンテンツスキャンで検出されずパージで消える）。完全なクラス名のマップ / safelist を使っているか 【担当: web-designer】
- [ ] **`@apply` の濫用**: `@apply` でユーティリティを寄せ集めて実質独自 CSS を再構築していないか（コンポーネント抽出・`@theme` トークンの検討） 【担当: web-designer】
- [ ] **クラス順序**: `prettier-plugin-tailwindcss` による自動整列に委ねているか（手動並び替えの指摘を避ける） 【担当: web-designer】
- [ ] **任意値の乱用**: `w-[137px]` のような任意値を多用してテーマから外れていないか。デザイントークン（`@theme` / config）で拡張すべき箇所ではないか 【担当: web-designer】
- [ ] **バージョン整合**: v4 で `tailwind.config.js` 前提の記事を適用していないか、v3 で `@theme` を使っていないか 【担当: web-designer】

### 2.3 Vitest / Jest（ユニットテスト）

- [ ] **テストの独立性**: テストが実行順序に依存していないか（共有状態・グローバル変数の書き換え残り）。単体で実行しても pass するか 【担当: test-engineer】
- [ ] **非同期テストの await 漏れ**: `async` テストで `await` / `return` を漏らして Promise を投げっぱなしにしていないか（アサーション前にテストが終了し **silent pass** になる） 【担当: test-engineer】
- [ ] **モックのリセット漏れ**: `beforeEach` / `afterEach` で `vi.clearAllMocks()` / `jest.resetAllMocks()` を行い、モック状態がテスト間で漏れないようにしているか 【担当: test-engineer】
- [ ] **スナップショットの濫用**: 巨大 / 意味の薄いスナップショットで実質的なアサーションを代替していないか。壊れても中身を確認せず更新する運用になっていないか 【担当: test-engineer】
- [ ] **カバレッジ偽装**: 実行するだけでアサーションのないテスト（カバレッジは上がるが検証していない）になっていないか 【担当: test-engineer】
- [ ] **ランナーの混在**: 同一プロジェクトで Vitest / Jest を二重化していないか。CI で `vitest run`（単発）を使い watch で停止しない構成か 【担当: test-engineer】

### 2.4 Playwright（E2E）

- [ ] **セレクタの脆さ**: CSS / XPath セレクタに依存していないか。`getByRole` / `getByLabel` / `getByTestId` などユーザー可視 / 明示コントラクトのロケータを優先しているか 【担当: test-engineer】
- [ ] **固定 sleep**: `waitForTimeout()`（固定待機）でタイミングを合わせていないか。`await expect(locator).toBeVisible()` 等の Web-First アサーション（自動待機・リトライ）を使っているか 【担当: test-engineer】
- [ ] **テスト間の状態共有**: 各テストが独自のデータ / cookie / ストレージで独立実行されるか（カスケード失敗の防止） 【担当: test-engineer】
- [ ] **外部依存の扱い**: サードパーティ自体をテスト対象にしていないか。外部依存はモック / スタブしているか 【担当: test-engineer】

### 2.5 Sass / Bootstrap（スタイリング）

- [ ] **ネスト深度**: セレクタのネストが深すぎて詳細度が高騰・上書き困難になっていないか（3 段程度を上限の目安に） 【担当: web-designer】
- [ ] **`@extend` vs mixin**: `@extend` で予期せぬセレクタ結合・出力膨張を招いていないか（引数を伴う再利用は mixin が適切） 【担当: web-designer】
- [ ] **変数 vs CSS カスタムプロパティ**: 実行時に変化させたい値を Sass 変数（コンパイル時固定）で扱っていないか。テーマ切替等は CSS カスタムプロパティが適切ではないか 【担当: web-designer】
- [ ] **`@use` への移行**: 新規で `@import`（Sass）を使っていないか。`@use` / `@forward` を用いているか 【担当: web-designer】
- [ ] **Bootstrap のバージョン混在**: v4 / v5 の記法・クラスを混在させていないか（ユーティリティ名・グリッドが変わる） 【担当: web-designer】
- [ ] **Bootstrap のカスタマイズ方法**: Sass 変数の上書きで統一しているか、後付けの上書き CSS が乱立していないか。Bootstrap と Tailwind を無計画に併用していないか（設計思想の衝突・ユーティリティ名の重複） 【担当: web-designer】

### 2.6 検出のヒント（grep 例）

差分の該当箇所を素早く特定するための検索パターン。ヒットした周辺で上記チェックリストを確認する。

| リスク | 検索パターン（例） | 確認事項 |
|-------|------------------|---------|
| 秘匿値のクライアント露出 | `VITE_` | 秘密鍵・トークンに付けていないか |
| Tailwind 動的クラス | `` text-${ `` / `` bg-${ `` / `` -${ `` | 補間でクラス名を組んでいないか |
| 非同期テストの await 漏れ | `it(` / `test(` の `async` に対する `await expect` | Promise を投げっぱなしにしていないか |
| モックのリセット漏れ | `vi.fn(` / `jest.fn(` / `vi.mock(` | `clearAllMocks` / `resetAllMocks` の有無 |
| Playwright 脆いセレクタ | `page.click("."` / `locator("//` / `waitForTimeout(` | ロール系ロケータ・自動待機に置換すべきか |
| Sass 非推奨 import | `@import` | `@use` / `@forward` に移行すべきか |

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 秘匿値への `VITE_` 付与（クライアント露出） | Critical | 鍵・トークンのバンドル埋め込み漏洩 |
| 非同期テストの await 漏れ（silent pass） | High | 検証が実行されず、壊れても緑になる |
| アサーションのないテスト（カバレッジ偽装） | High | 品質保証の空洞化 |
| Tailwind の動的クラス補間（パージ消滅） | High | 本番ビルドでスタイルが欠落 |
| モックのリセット漏れ・テストの順序依存 | High〜Medium | 偽陽性 / 偽陰性・不安定テスト |
| Playwright の CSS/XPath セレクタ・固定 sleep | Medium〜High | フレーク・DOM 変更で壊れる |
| Bootstrap のバージョン混在 | Medium | レイアウト崩壊・クラス不整合 |
| `@apply` / `@extend` の濫用・任意値の乱用 | Medium〜Low | 保守性低下・出力膨張 |
| Sass ネスト過多・`@import` 新規使用 | Medium〜Low | 詳細度高騰・非推奨 API |
| Tailwind クラス順序・過剰な動的 import | Low | 整列規約・軽微な性能 |

### NG / OK 例（Tailwind の動的クラス）

```jsx
// NG: 文字列補間はコンテンツスキャンで検出されずパージで消える
<span className={`text-${color}-500`}>{label}</span>

// OK: 完全なクラス名をマップで持つ（スキャン対象になる）
const COLOR = { red: "text-red-500", green: "text-green-500" };
<span className={COLOR[color]}>{label}</span>
```

### NG / OK 例（Playwright の待機とセレクタ）

```ts
// NG: 脆い CSS セレクタ + 固定 sleep
await page.click(".btn.primary");
await page.waitForTimeout(3000);

// OK: ロールベースのロケータ + 自動待機アサーション
await page.getByRole("button", { name: "保存" }).click();
await expect(page.getByText("保存しました")).toBeVisible();
```

### NG / OK 例（Vitest の await 漏れ）

```ts
// NG: await がなく、アサーション解決前にテストが終了して緑になる（silent pass）
it("fetches user", async () => {
  expect(fetchUser(1)).resolves.toEqual({ id: 1 });
});

// OK: await で Promise の解決を待ってから判定する
it("fetches user", async () => {
  await expect(fetchUser(1)).resolves.toEqual({ id: 1 });
});
```

## 4. 関連プロファイル参照

差分の内容に応じて以下を併読する。

| 対象 | プロファイル |
|------|-------------|
| JavaScript 言語共通の観点 | `${CLAUDE_PLUGIN_ROOT}/references/languages/javascript.md` |
| TypeScript 言語共通の観点 | `${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md` |
| CSS 言語共通の観点（詳細度・レイアウト・アクセシビリティ） | `${CLAUDE_PLUGIN_ROOT}/references/languages/css.md` |
| React / Vue 等のコンポーネント FW 観点 | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` / `vue.md` |
| 指摘の重要度付与・重複統合 | `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` |
