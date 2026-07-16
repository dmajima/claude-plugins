# フロントエンドツールチェーン フレームワークプロファイル

対象言語プロファイル: [JavaScript 規約](../../skills/coding-javascript/references/conventions.md) / [TypeScript 規約](../../skills/coding-typescript/references/conventions.md) / [CSS 規約](../../skills/coding-css/references/conventions.md)（言語規約はそちらに従う。本ファイルは各ツール固有規約のみ）

ビルド（Vite）・スタイリング（Tailwind / Sass / Bootstrap）・テスト（Vitest / Playwright / Jest）のツール群を横断的に扱う。React / Vue 等の FW 規約は [react.md](react.md) / [vue.md](vue.md) を参照。

準拠する主要出典:

- Vite 公式 <https://vite.dev/>（`vite.config.ts` / 環境変数 / CLI）
- Tailwind CSS 公式 <https://tailwindcss.com/docs>（ユーティリティファースト / v4 の `@theme`）
- Vitest 公式 <https://vitest.dev/>
- Playwright 公式 <https://playwright.dev/>（ロケータ / ベストプラクティス）
- Jest 公式 <https://jestjs.io/>
- Sass 公式 <https://sass-lang.com/documentation/> / Bootstrap 公式 <https://getbootstrap.com/docs/>

（本ファイル末尾の「8. 出典一覧」に個別ページを集約）

## 1. 検出

| ツール | 検出マーカー |
|--------|-------------|
| Vite | devDependencies に `vite`。`vite.config.ts` / `vite.config.js` |
| Tailwind CSS | dependencies/devDependencies に `tailwindcss`。v3: `tailwind.config.js` / v4: CSS 内の `@import "tailwindcss"` |
| Vitest | devDependencies に `vitest`。`vitest.config.ts` または `vite.config.ts` の `test` フィールド |
| Playwright | devDependencies に `@playwright/test`。`playwright.config.ts` |
| Jest | devDependencies に `jest`。`jest.config.js` / `jest.config.ts` / `package.json` の `jest` フィールド |
| Sass | devDependencies に `sass`。`.scss` / `.sass` ファイル |
| Bootstrap | dependencies に `bootstrap` |

このユーザの主構成: Vite 6 / Tailwind CSS 4 / Vitest / Playwright。

## 2. Vite

### 2.1 プロジェクト構造・配置規則

- 設定ファイルは **`vite.config.ts`**（プロジェクトルート）。`defineConfig({ ... })` で定義する。
- エントリは **`index.html`**（ルート）。Vite は `index.html` を起点にモジュールを解決する（`public/` は無加工で配信）。

### 2.2 ツール固有の命名・実装規約

- **環境変数**: クライアントに公開する変数は **`VITE_`** プレフィクスを付ける（Vite 公式「Env Variables and Modes」<https://vite.dev/guide/env-and-mode>）。コードからは **`import.meta.env.VITE_XXX`** で参照する。プレフィクスのない変数はクライアントに露出しない。
- `.env` / `.env.local` / `.env.[mode]`（`development` / `production`）を読み込む。

### 2.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| dev | `vite`（= `vite dev` / `vite serve`） | 開発サーバ（HMR） |
| build | `vite build` | 本番ビルド（`dist/`） |
| preview | `vite preview` | ビルド成果物のローカル確認（本番配信の代替ではない） |

### 2.4 ベストプラクティス・アンチパターン

- **秘匿値に `VITE_` を付けない**（`VITE_` 付き変数はクライアントバンドルに埋め込まれ露出する）。
- `vite preview` を本番サーバ代わりに使わない（動作確認専用）。

## 3. Tailwind CSS

### 3.1 プロジェクト構造・配置規則

- **v4（CSS-first。Tailwind 公式「Theme」<https://tailwindcss.com/docs/theme>）**: CSS ファイルの先頭に **`@import "tailwindcss";`** を書き、テーマは **`@theme { --color-...: ...; }`** ディレクティブで定義する。**`content` 配列は不要**（自動でテンプレートを検出）。JS の `tailwind.config.js` は原則不要。
- **v3**: `tailwind.config.js` に **`content: [...]`** 配列でスキャン対象を列挙し、CSS では `@tailwind base; @tailwind components; @tailwind utilities;` を記述する。
- v3 と v4 で設定方式が根本的に異なるため、**プロジェクトのバージョンを先に確認**してから設定を編集する。

### 3.2 ツール固有の命名・実装規約

- **ユーティリティファースト**（Tailwind 公式「Styling with utility classes」<https://tailwindcss.com/docs/styling-with-utility-classes>）: `class` に小さな単機能ユーティリティ（`flex` `px-4` `text-sm` 等）を組み合わせてスタイリングする。
- **クラス順序**: **`prettier-plugin-tailwindcss`**（Tailwind 公式が提供する Prettier プラグイン <https://github.com/tailwindlabs/prettier-plugin-tailwindcss>）による**自動整列**が慣習。手動での並び順統一より本プラグインに委ねる。
- v4 のテーマトークンは `--color-*` `--font-*` `--text-*` `--breakpoint-*` `--spacing-*` `--radius-*` `--shadow-*` 等の名前空間で定義し、対応するユーティリティが自動生成される。

### 3.3 ツールチェーン

| 用途 | コマンド / 設定 | 備考 |
|------|---------------|------|
| v4 セットアップ（Vite） | `@tailwindcss/vite` プラグインを `vite.config.ts` に追加 | v4 の推奨統合 |
| v3 セットアップ | `npx tailwindcss init`（`tailwind.config.js` 生成） | v3 のみ |

### 3.4 ベストプラクティス・アンチパターン

- **バージョンに合った設定方式を使う**（v4 で `tailwind.config.js` 前提の記事を適用しない、v3 で `@theme` を使わない）。
- クラスの並びは `prettier-plugin-tailwindcss` に統一させ、レビューでの並び順指摘を避ける。

## 4. Vitest

### 4.1 プロジェクト構造・配置規則

- テストファイル名は **`*.test.ts`** / **`*.spec.ts`**（既定の include。`.tsx` / `.js` 等も対象）。
- 設定は **`vitest.config.ts`**、または **`vite.config.ts` の `test` フィールド**に記述する（Vite の設定を共有できるのが Vitest の利点）。

### 4.2 ツール固有の命名・実装規約

- テスト構造は **`describe` / `it`（または `test`）/ `expect`**。
- モック等のユーティリティは **`vi`** グローバル（Jest の `jest` に相当）。
- **Testing Library との併用**（`@testing-library/react` / `@testing-library/vue`）が一般的。DOM 環境は `jsdom` / `happy-dom` を `test.environment` で指定する。

### 4.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| test（watch） | `vitest` | 変更監視付き実行 |
| test（単発） | `vitest run` | CI 向け 1 回実行 |
| カバレッジ | `vitest run --coverage` | |

### 4.4 ベストプラクティス・アンチパターン

- **Testing Library の役割ベースクエリ**（`getByRole` 等）を優先し、実装詳細（クラス名・内部関数）に依存したテストを避ける（Testing Library 公式「Priority」<https://testing-library.com/docs/queries/about#priority>）。
- 単発実行は `vitest run` を用いる（`vitest` は watch モードのため CI では停止しない）。

## 5. Playwright

### 5.1 プロジェクト構造・配置規則

- 設定は **`playwright.config.ts`**（`testDir` でテストディレクトリを指定。**`e2e/`** または `tests/` が慣習）。
- E2E テストは `testDir` 配下に配置する。

### 5.2 ツール固有の命名・実装規約

- **ロケータ優先順位**（Playwright 公式「Best Practices」<https://playwright.dev/docs/best-practices>。ユーザー可視の属性を優先し、CSS / XPath を避ける）:
  1. `getByRole`（ロールベース。DOM 変更に最も強い）
  2. `getByText`
  3. `getByLabel`
  4. `getByTestId`（テスト用の明示的コントラクト）
  5. CSS セレクタ / XPath（**壊れやすいため回避**）
- **Web-First アサーション**: `isVisible()` 等の手動チェックではなく **`await expect(locator).toBeVisible()`** を使う（自動で待機・リトライする）。

### 5.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| セットアップ | `npm init playwright@latest` | 設定・ブラウザ・サンプル生成 |
| test | `npx playwright test` | 全ブラウザで E2E 実行 |
| UI モード | `npx playwright test --ui` | デバッグ用 |
| レポート | `npx playwright show-report` | HTML レポート表示 |

### 5.4 ベストプラクティス・アンチパターン

- **テスト分離**: 各テストは独自のデータ・cookie・ストレージで独立実行する（カスケード失敗を防ぐ）。
- **ユーザー可視の振る舞いをテスト**し、実装詳細に依存しない。
- **CSS / XPath ロケータを避け**、`getByRole` 等のユーザー可視ロケータを優先する。
- 外部依存はモックし、サードパーティ自体はテスト対象にしない。

## 6. Jest

Vitest を採用しないプロジェクト（既存の CRA / 従来の Node プロジェクト等）向け。

### 6.1 プロジェクト構造・配置規則

- 設定は **`jest.config.js`** / **`jest.config.ts`**、または `package.json` の **`jest`** フィールド。
- テストファイル名は **`*.test.js`** / **`*.spec.js`**（`__tests__/` ディレクトリも既定で対象）。

### 6.2 ツール固有の命名・実装規約

- テスト構造は **`describe` / `it`（`test`）/ `expect`** で、**Vitest と API 互換**（Vitest は Jest 互換 API として設計されている。移行ガイド: <https://vitest.dev/guide/migration>）。
- モックは **`jest`** グローバル（Vitest の `vi` に相当）。
- TS 実行には `ts-jest` または `babel-jest` を用いる。

### 6.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| test | `jest`（`npm test`） | |
| watch | `jest --watch` | |
| カバレッジ | `jest --coverage` | |

### 6.4 ベストプラクティス・アンチパターン

- **Vitest との混在を避ける**（同一プロジェクトでランナーを二重化しない。どちらか一方に統一する）。
- Vite ベースの新規プロジェクトでは Vitest を優先し、Vite 設定を共有する。

## 7. Sass / Bootstrap

（簡潔に。CSS 全般の規約は [CSS 規約](../../skills/coding-css/references/conventions.md) を参照）

### 7.1 プロジェクト構造・配置規則

- **Sass**: 拡張子は **`.scss`**（CSS 上位互換の SCSS 構文。インデント構文の `.sass` もあるが SCSS が主流）。部分ファイルは **`_name.scss`**（アンダースコア始まり）とし、`@use` で読み込む。
- **Bootstrap**: CSS/JS を読み込むか、Sass ソースを `@use "bootstrap"` で取り込みカスタマイズする。

### 7.2 ツール固有の命名・実装規約

- **Sass のモジュールは `@use` を使う**（Sass 公式「@use」<https://sass-lang.com/documentation/at-rules/use/>。旧来の `@import` は非推奨化されており、名前空間衝突を防ぐ `@use` / `@forward` を用いる）。
- **Bootstrap**: ユーティリティクラス（`d-flex` `mt-3` 等）とコンポーネント（`btn` `card` 等）を組み合わせる。Tailwind と併用すると設計思想（コンポーネント指向 vs ユーティリティファースト）が競合しやすいため、原則どちらかに寄せる。

### 7.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| Sass ビルド | Vite 等のバンドラが `.scss` を自動処理（`sass` パッケージ導入時） | 単体では `sass input.scss output.css` |

### 7.4 ベストプラクティス・アンチパターン

- **`@import`（Sass）を新規で使わない**（`@use` / `@forward` に移行済み）。
- **Bootstrap と Tailwind を無計画に併用しない**（ユーティリティ名・リセットの衝突を招く）。

## 8. 出典一覧

| 対象 | 出典 | URL |
|------|------|-----|
| Vite 設定 | Vite 公式 | <https://vite.dev/config/> |
| Vite 環境変数（`VITE_`） | Vite 公式 | <https://vite.dev/guide/env-and-mode> |
| Vite CLI | Vite 公式 | <https://vite.dev/guide/cli.html> |
| Tailwind ユーティリティファースト | Tailwind 公式 | <https://tailwindcss.com/docs/styling-with-utility-classes> |
| Tailwind v4 テーマ（`@theme`） | Tailwind 公式 | <https://tailwindcss.com/docs/theme> |
| Tailwind クラス整列プラグイン | Tailwind Labs | <https://github.com/tailwindlabs/prettier-plugin-tailwindcss> |
| Vitest 設定 | Vitest 公式 | <https://vitest.dev/config/> |
| Vitest → Jest 互換 / 移行 | Vitest 公式 | <https://vitest.dev/guide/migration> |
| Testing Library クエリ優先順位 | Testing Library 公式 | <https://testing-library.com/docs/queries/about#priority> |
| Playwright ロケータ | Playwright 公式 | <https://playwright.dev/docs/locators> |
| Playwright ベストプラクティス | Playwright 公式 | <https://playwright.dev/docs/best-practices> |
| Jest 設定 | Jest 公式 | <https://jestjs.io/docs/configuration> |
| Sass `@use` | Sass 公式 | <https://sass-lang.com/documentation/at-rules/use/> |
| Bootstrap ドキュメント | Bootstrap 公式 | <https://getbootstrap.com/docs/> |
