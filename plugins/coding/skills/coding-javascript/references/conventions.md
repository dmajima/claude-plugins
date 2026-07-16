# JavaScript 言語プロファイル

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.js`, `.mjs`（ESM 明示）, `.cjs`（CommonJS 明示） |
| マーカーファイル | `package.json`（同階層・上位に `tsconfig.json` が **無い** 場合に JavaScript と判定） |

補足: `tsconfig.json` が存在する場合は [TypeScript 規約](../../coding-typescript/references/conventions.md) を優先する。両者が混在するプロジェクトでは両プロファイルを併用する。

## 2. デファクトスタンダード規約

JavaScript には言語公式の単一標準スタイルガイドが存在しない。本プロファイルでは以下を基準とする。

- **フォーマット基準**: Prettier デフォルト設定（https://prettier.io/docs/options）
- **命名・慣習の代表例**: Airbnb JavaScript Style Guide（https://github.com/airbnb/javascript）— 広く採用される慣習の一例として参照する。ただし Airbnb はシングルクォート等 Prettier デフォルトと一部異なるため、プロジェクトの Prettier / ESLint 設定を常に優先する
- **言語仕様リファレンス**: MDN JavaScript（https://developer.mozilla.org/en-US/docs/Web/JavaScript）

> 命名・クォート等に「唯一の正解」はない。プロジェクトの `.prettierrc` / `eslint.config.js` が存在すればそれが最終的な正となり、本章はそれらが無い場合のデフォルトである。

### 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| クラス | PascalCase | `OrderService` |
| 関数/メソッド | camelCase | `calculateTotal` |
| 変数 | camelCase | `itemCount` |
| 定数（モジュールレベルの不変値） | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| ファイル名 | kebab-case または camelCase（プロジェクト内で統一） | `order-service.js` / `orderService.js` |

補足: React コンポーネント等、ファイル名を PascalCase にする慣習を持つフレームワークもある（[react.md](../../../references/frameworks/react.md) 参照）。

### 2.2 インデント・フォーマット

Prettier デフォルト値。出典: https://prettier.io/docs/options

| 項目 | 規定 |
|------|------|
| インデント | スペース 2 個（`tabWidth: 2`, `useTabs: false`） |
| 行長目安 | 80 文字（`printWidth: 80`） |
| 文字列引用符 | ダブルクォート（`singleQuote: false`）。プロジェクト設定で単一に変更されている場合はそれに従う |
| 末尾セミコロン | あり（`semi: true`） |
| 末尾カンマ | すべてに付与（`trailingComma: "all"`、Prettier 3.x デフォルト） |
| アロー関数の括弧 | 常に付与（`arrowParens: "always"`） |

### 2.3 主要スタイル規則

- **モジュール形式**: ESM（`import` / `export`）を第一選択とする。CommonJS（`require` / `module.exports`）はレガシーコード・一部の設定ファイル（`eslint.config.cjs` 等）用途に限る
- `package.json` の `"type": "module"` 指定時、`.js` は ESM として解釈される。CommonJS を混在させる場合は `.cjs` 拡張子を使う
- 変数宣言は `const` を第一選択、再代入が必要な場合のみ `let`。`var` は使用しない
- 比較は厳密等価（`===` / `!==`）を使い、抽象等価（`==`）は使わない
- 文字列生成はテンプレートリテラル（`` `${x}` ``）を優先する

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| パッケージ管理 | `npm` / `pnpm` / `yarn` | ロックファイル（`package-lock.json` / `pnpm-lock.yaml` / `yarn.lock`）で判定 |
| 実行 | `node <file>` | Node.js 18+ は `node --watch` でウォッチ実行可 |
| テスト | `vitest` / `jest` | `node --test`（Node.js 標準テストランナー）も選択肢 |
| Lint | `eslint` | 現行は flat config（`eslint.config.js`）。ESLint 9 以降は flat config が既定 |
| フォーマット | `prettier` | `prettier --write .` |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コード |
| `.prettierrc` / `.prettierrc.json` / `.prettierrc.js` 等 | フォーマット規則（本プロファイル 2.2 を上書き） |
| `eslint.config.js`（flat config, 現行） | Lint ルール |
| `.eslintrc` / `.eslintrc.json` / `.eslintrc.cjs`（レガシー） | Lint ルール（ESLint 8 以前の形式） |
| `package.json` の `"type"` フィールド | `"module"`（ESM）/ `"commonjs"`（CJS）の既定モジュール形式 |

## 4. イディオム・ベストプラクティス

- `const` 優先・`let` 限定・`var` 禁止
- 厳密等価 `===` / `!==` を使う
- 分割代入（destructuring）でオブジェクト・配列から値を取り出す: `const { id, name } = user`
- オプショナルチェーン `?.` と Null 合体 `??` で undefined / null を安全に扱う
- 非同期処理は `async` / `await` を優先し、生の `.then()` チェーンのネストを避ける
- 配列操作は `map` / `filter` / `reduce` / `find` 等の高階メソッドを優先する（副作用のある `for` ループより宣言的）
- エラーは `Error`（またはそのサブクラス）を `throw` する。文字列を throw しない
- アンチパターン: 暗黙のグローバル変数、`==` による型強制比較、`var` の巻き上げ依存、未 `catch` の Promise

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| `TypeError: Cannot read properties of undefined (reading 'x')` | undefined / null のプロパティにアクセス | オプショナルチェーン `?.`、事前の存在チェック、初期値の付与 |
| `ReferenceError: x is not defined` | 未宣言の変数参照、スコープ外参照、`import` 漏れ | 宣言・import の確認、スペルミス確認 |
| `SyntaxError: Cannot use import statement outside a module` | CommonJS コンテキストで ESM 構文を使用 | `package.json` に `"type": "module"` を追加、または `.mjs` 拡張子を使う |
| `Error [ERR_REQUIRE_ESM]` | CommonJS の `require()` で ESM 専用パッケージを読み込み | `import` に書き換える、または動的 `import()` を使う |
| `UnhandledPromiseRejection` | Promise の reject を catch していない | `try/catch`（async/await）または `.catch()` を付与 |

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| Express / NestJS（Node.js サーバー） | [node.md](../../../references/frameworks/node.md) |
| React / Next.js | [react.md](../../../references/frameworks/react.md) |
| Vue / Nuxt | [vue.md](../../../references/frameworks/vue.md) |
| Vite / Tailwind / Vitest / Jest / Playwright（フロントエンドツール） | [frontend-tooling.md](../../../references/frameworks/frontend-tooling.md) |
