# TypeScript 言語プロファイル

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.ts`, `.tsx`（JSX を含む TS） |
| マーカーファイル | `tsconfig.json`（プロジェクトルートでの検出対象） |

補足: TypeScript は JavaScript のスーパーセットであり、[JavaScript 規約](../../coding-javascript/references/conventions.md) の規約（命名・フォーマット・イディオム・ツールチェーン）を **継承** する。本プロファイルは TypeScript 固有の追加規約のみを記載する。

## 2. デファクトスタンダード規約

**準拠規約**:
- TypeScript 公式 Do's and Don'ts（https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html）
- typescript-eslint recommended 設定（https://typescript-eslint.io/users/configs/#recommended）
- フォーマットは JavaScript と同じく Prettier デフォルトに従う（[JavaScript 規約](../../coding-javascript/references/conventions.md) の 2.2 を参照）

### 2.1 命名規則

JavaScript の命名規則（[JavaScript 規約](../../coding-javascript/references/conventions.md) の 2.1）に加え、型に関する規則を追加する。

| 対象 | 規則 | 例 |
|------|------|-----|
| 型エイリアス / インターフェース | PascalCase | `type OrderId = string` / `interface UserProfile` |
| enum（および列挙メンバー） | PascalCase | `enum OrderStatus { Pending, Shipped }` |
| ジェネリクス型パラメータ | `T` から始まる簡潔な名前、または意味のある PascalCase | `T`, `TKey`, `TValue` |

- **インターフェースに `I` プレフィクスを付けない**（`IUser` ではなく `User`）。これは TypeScript チーム自身のコーディング規約（https://github.com/microsoft/TypeScript/wiki/Coding-guidelines）に由来し、コミュニティで広く踏襲される慣習である
- 型名に接頭辞・接尾辞（`Type` / `Interface`）は付けない

### 2.2 インデント・フォーマット

[JavaScript 規約](../../coding-javascript/references/conventions.md) の 2.2 と同一（Prettier デフォルト）。TypeScript 固有の追加フォーマット規則はない。

### 2.3 主要スタイル規則（型に関する規約）

- `strict: true`（`tsconfig.json`）を前提とする。これにより `strictNullChecks` / `noImplicitAny` 等が有効になる
- `any` を避け、型が不明な値には `unknown` を使い、使用前に型を絞り込む
- 公開 API（エクスポートする関数・メソッド）は戻り値型を明示する。内部関数は推論に委ねてよい
- 型の絞り込みは型ガード（`typeof` / `instanceof` / ユーザー定義型ガード `x is T`）を優先し、型アサーション（`as`）は最小限にする
- プリミティブは小文字の型（`string` / `number` / `boolean`）を使う。`String` / `Number` / `Object` 等のラッパー型は使わない（公式 Do's and Don'ts）

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| 型チェック | `tsc --noEmit` | 型検査のみ。JS 出力は生成しない |
| ビルド | バンドラに委譲（`vite build` 等） | 実運用では `tsc` 単体ビルドよりバンドラ（Vite / esbuild / tsup）に委譲する構成が一般的 |
| テスト | `vitest` / `jest`（`ts-jest` または `@swc/jest`） | Vitest は TS を追加設定なしで実行できる |
| Lint | `eslint` + `typescript-eslint` | 型情報を用いた Lint は `parserOptions.project` を指定 |
| フォーマット | `prettier` | JS と共通 |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `tsconfig.json` | `strict` / `target` / `module` / `paths`（パスエイリアス）等。型規約の最終的な正 |
| `eslint.config.js` / `.eslintrc*` | Lint ルール（`typescript-eslint` を含む） |
| `.prettierrc*` / `.editorconfig` | JS と共通（[JavaScript 規約](../../coding-javascript/references/conventions.md) 参照） |

## 4. イディオム・ベストプラクティス

- JavaScript のイディオム（[JavaScript 規約](../../coding-javascript/references/conventions.md) の 4）をすべて継承する
- ユニオン型で取りうる値を明示する: `type Result = "ok" | "error"`
- 判別可能ユニオン（discriminated union）で状態を型安全に分岐する（共通の判別プロパティ `kind` / `type` を持たせる）
- `satisfies` 演算子（TS 4.9+）で「型の適合を検査しつつリテラル型の推論を保持」する
- `readonly` / `readonly T[]` / `as const` でイミュータブルを表現する
- ユーティリティ型（`Partial` / `Pick` / `Omit` / `Record` / `Required` 等）で既存型から派生型を作る（https://www.typescriptlang.org/docs/handbook/utility-types.html）
- 外部入力（API レスポンス・フォーム）は **コンパイル時の型だけでは保証されない**。ランタイム検証ライブラリ（`zod` 等）でスキーマ検証し、`z.infer` で型を導出する。OpenAPI 定義からは `openapi-typescript` で型を生成し、`zod` と併用する構成が有効
- アンチパターン: 安易な `any`、`as any` による型エラーの握り潰し、非 null アサーション `!` の多用、`@ts-ignore` / `@ts-expect-error` の常用

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| `TS2307: Cannot find module 'X' or its corresponding type declarations` | モジュール未インストール、型定義（`@types/*`）欠如、`paths` 設定漏れ | パッケージ・`@types/*` の導入、`tsconfig.json` の `paths` / `baseUrl` 確認 |
| `TS2345: Argument of type 'X' is not assignable to parameter of type 'Y'` | 引数の型不一致 | 引数の型修正、関数シグネチャの見直し、必要なら型ガードで絞り込み |
| `TS18048: 'x' is possibly 'undefined'` | `strictNullChecks` 下で undefined の可能性がある値を使用 | オプショナルチェーン `?.`、事前の存在チェック、初期値の付与 |
| `TS2322: Type 'X' is not assignable to type 'Y'` | 代入先の型に適合しない値の代入 | 型定義の修正、ユニオン型の見直し |
| `TS7006: Parameter 'x' implicitly has an 'any' type` | `noImplicitAny` 下でパラメータの型注釈なし | 明示的な型注釈を付与 |

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| Express / NestJS（Node.js サーバー） | [node.md](../../../references/frameworks/node.md) |
| React / Next.js | [react.md](../../../references/frameworks/react.md) |
| Vue / Nuxt | [vue.md](../../../references/frameworks/vue.md) |
| Vite / Tailwind / Vitest / Jest / Playwright（フロントエンドツール） | [frontend-tooling.md](../../../references/frameworks/frontend-tooling.md) |
