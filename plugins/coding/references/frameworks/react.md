# React / Next.js フレームワークプロファイル

対象言語プロファイル: [JavaScript 規約](../../skills/coding-javascript/references/conventions.md) / [TypeScript 規約](../../skills/coding-typescript/references/conventions.md)（言語規約はそちらに従う。本ファイルは FW 固有規約のみ）

準拠する主要出典:

- React 公式「Rules of React」<https://react.dev/reference/rules>
- React 公式「Rules of Hooks」<https://react.dev/reference/rules/rules-of-hooks>
- React 公式「You Might Not Need an Effect」<https://react.dev/learn/you-might-not-need-an-effect>
- Next.js 公式「Project structure and organization」<https://nextjs.org/docs/app/getting-started/project-structure>

（本ファイル末尾の「4. 出典一覧」に個別ページを集約）

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| React | `package.json` の dependencies に `react` / `react-dom`。`.jsx` / `.tsx` ファイルの存在 |
| Next.js | dependencies に `next`。`next.config.js` / `next.config.ts` / `next.config.mjs`。`app/` または `pages/` ディレクトリ |
| Vite + React | devDependencies に `@vitejs/plugin-react`（ビルド・環境変数・テストは [frontend-tooling.md](frontend-tooling.md) を参照） |

このユーザの主構成: React 19 + Vite。React 本体を厚めに扱う。

## 2. React

React 公式は「関数コンポーネント + Hooks」を前提とする。クラスコンポーネントは引き続き動作するがレガシー扱いであり、新規実装では関数コンポーネントを採用する（React 公式ドキュメントの解説・API がすべて関数コンポーネント + Hooks を前提としている）。

### 2.1 プロジェクト構造・配置規則

React 本体はディレクトリ構成を規定しない（unopinionated）。慣習的な配置は以下。

| 項目 | 慣習 |
|------|------|
| エントリポイント（Vite） | `index.html`（ルート）→ `src/main.tsx` → `src/App.tsx` |
| コンポーネント配置 | `src/components/` 等に 1 コンポーネント 1 ファイルで配置 |
| カスタムフック配置 | `src/hooks/` 等にまとめる（`useXxx.ts`） |
| コロケーション | コンポーネントと密結合なスタイル・テスト・型は同一ディレクトリに併置してよい |

- Vite 構成では `index.html` がアプリのエントリであり、`<script type="module" src="/src/main.tsx">` で読み込む（Vite の詳細は [frontend-tooling.md](frontend-tooling.md)）。

### 2.2 FW 固有の命名・実装規約

| 対象 | 規則 | 例 |
|------|------|-----|
| コンポーネント名 | PascalCase（React はコンポーネントを大文字始まりで識別する。小文字始まりは DOM タグ扱いになる） | `OrderList`, `UserCard` |
| コンポーネントファイル名 | コンポーネント名に合わせる慣習（PascalCase） | `UserCard.tsx` |
| カスタムフック | `use` プレフィクス + camelCase（React はこの命名で Hook を識別する） | `useOnlineStatus`, `useCart` |
| props 型 | TypeScript の `interface` または `type` で明示定義する | `interface Props { userId: string }` |
| イベントハンドラ | `handle` プレフィクス（慣習） | `handleClick`, `handleSubmit` |

主要な実装規約（React 公式「Rules of React」<https://react.dev/reference/rules>）:

- **コンポーネントと Hooks は純粋であること（Components and Hooks must be pure）**: レンダー中に副作用を起こさない。props / state は不変（immutable）として扱い、レンダー中に書き換えない。
- **コンポーネント・Hooks を直接呼び出さない（React calls Components and Hooks）**: コンポーネントは JSX 内で使い、関数として直接呼ばない。Hooks を通常の値として引き回さない。
- **Rules of Hooks（<https://react.dev/reference/rules/rules-of-hooks>）**:
  - **Only call Hooks at the top level** — ループ・条件分岐・ネストした関数の中で Hook を呼ばない。早期 return より前、React 関数のトップレベルで呼ぶ。
  - **Only call Hooks from React functions** — Hook は関数コンポーネントまたはカスタムフックの中からのみ呼ぶ。通常の JS 関数から呼ばない。
- **props / state / context の型を明示**（TypeScript 使用時）。
- **リストレンダーの `key`**: `map` で要素を描画する際は一意で安定した `key` を付与する。配列インデックスを `key` にするのは要素の並び替え・挿入削除がある場合は避ける（差分計算が破綻し状態が混線する）。

### 2.3 ツールチェーン

Vite + React（本ユーザ構成）を基準に記載。詳細は [frontend-tooling.md](frontend-tooling.md)。

| 用途 | コマンド | 備考 |
|------|---------|------|
| scaffold | `npm create vite@latest <name> -- --template react-ts` | React + TS の Vite テンプレート |
| dev | `vite`（`npm run dev`） | 開発サーバ |
| build | `vite build`（TS 併用時は `tsc -b && vite build` が慣習） | 本番ビルド |
| preview | `vite preview` | ビルド成果物のローカル確認 |
| Lint | ESLint + `eslint-plugin-react-hooks` | Rules of Hooks / 依存配列を静的検査 |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コード |
| `eslint.config.js` / `.eslintrc.*` | Lint ルール（`eslint-plugin-react-hooks` の有無を確認） |
| `tsconfig.json` | TypeScript 設定 |

### 2.4 ベストプラクティス・アンチパターン

React 公式「You Might Not Need an Effect」<https://react.dev/learn/you-might-not-need-an-effect> に基づく。

- **useEffect の乱用を避ける**（公式が明示するアンチパターン）:
  - props / state から算出できる値は Effect で state に同期せず、**レンダー中に計算**する（派生値に `useEffect` + `setState` を使わない。必要なら `useMemo`）。
  - **ユーザーイベントに紐づく処理はイベントハンドラで行う**（Effect ではなく `onClick` 等で実行する）。
  - 外部ストアの購読は `useSyncExternalStore` を検討する。
- **useEffect の依存配列を正確に保つ**: Effect 内で参照する reactive な値（props / state / それらから作った値）はすべて依存配列に列挙する。`eslint-plugin-react-hooks` の `exhaustive-deps` に従う。依存を意図的に省くために配列を偽らない。
- **state のリフトアップ**: 複数の子で共有する状態は最も近い共通の親に持ち上げ、props で配布する（single source of truth）。
- **state / props を直接変更しない**（immutable に扱い、新しいオブジェクト・配列を生成して更新する）。
- **コンポーネントを関数として直接呼ばない**（`MyComponent()` ではなく `<MyComponent />`）。
- **クラスコンポーネントの新規追加を避ける**（関数コンポーネント + Hooks を採用）。

## 3. Next.js

Next.js には **App Router**（`app/`、現行の推奨）と **Pages Router**（`pages/`、従来方式・引き続きサポート）がある。新規は App Router を基本とし、既存が Pages Router の場合はそれに合わせる。両者は同一プロジェクト内で併存可能。

### 3.1 プロジェクト構造・配置規則

App Router のファイル規約（Next.js 公式「Project structure and organization」<https://nextjs.org/docs/app/getting-started/project-structure>）:

| ファイル | 拡張子 | 役割 |
|---------|--------|------|
| `layout` | `.js` `.jsx` `.tsx` | セグメント共通のレイアウト（ヘッダ・ナビ等）。ルート直下は Root Layout |
| `page` | `.js` `.jsx` `.tsx` | ルートを公開する UI。**このファイルがあって初めてルートが公開される** |
| `loading` | `.js` `.jsx` `.tsx` | ローディング UI（Suspense 境界） |
| `error` | `.js` `.jsx` `.tsx` | エラー UI（Error 境界）。Client Component である必要がある |
| `not-found` | `.js` `.jsx` `.tsx` | Not Found UI |
| `route` | `.js` `.ts` | API エンドポイント（Route Handlers。`GET` / `POST` 等を export） |
| `template` | `.js` `.jsx` `.tsx` | 再レンダーされるレイアウト |
| `default` | `.js` `.jsx` `.tsx` | Parallel Routes のフォールバック |

- **トップレベル**: `app/`（App Router）/ `pages/`（Pages Router）/ `public/`（静的アセット）/ `src/`（任意のソースフォルダ）。設定は `next.config.js`（`.ts` / `.mjs`）。
- **動的ルート**: `[slug]`（単一）/ `[...slug]`（catch-all）/ `[[...slug]]`（任意 catch-all）。値は `params` prop から取得。
- **Route Groups**: `(group)` は URL に含まれない整理用フォルダ。
- **Private Folders**: `_folder` はルーティング対象外（コロケーション用）。`app/` 内はデフォルトで安全にコロケーション可能（`page` / `route` がないセグメントは公開されない）。

### 3.2 FW 固有の命名・実装規約

- **Server Components / Client Components**: App Router のコンポーネントは既定で **Server Component**。ブラウザ側の状態・イベント・ブラウザ API（`useState` / `useEffect` / `onClick` 等）を使う場合は、ファイル先頭に **`'use client'`** ディレクティブを置き Client Component にする。
  - `'use client'` はできるだけツリーの**葉側**に置き、Client 境界を小さく保つ。
- **Route Handlers**: `route.ts` で `GET` / `POST` / `PUT` / `DELETE` 等の HTTP メソッド関数を export する。
- **Server Actions**: サーバ実行の関数には `'use server'` を付す。
- **メタデータ**: `metadata` エクスポートまたは `generateMetadata` 関数、`favicon` / `opengraph-image` 等の規約ファイルで定義する。

### 3.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| scaffold | `npx create-next-app@latest` | 対話式で App Router / TS / Tailwind 等を選択 |
| dev | `next dev`（`npm run dev`） | 開発サーバ |
| build | `next build` | 本番ビルド |
| start | `next start` | 本番サーバ起動（`next build` 後） |
| Lint | `next lint`（プロジェクトにより ESLint 直接呼び出し） | |

- **環境変数**: ブラウザに公開する変数は **`NEXT_PUBLIC_`** プレフィクスを付ける（付けない変数はサーバ専用）。`.env` / `.env.local` / `.env.production` / `.env.development` を読み込む（`.env.local` はバージョン管理対象外）。

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `next.config.js` / `.ts` / `.mjs` | Next.js 設定 |
| `tsconfig.json` | TypeScript 設定 |
| `eslint.config.*` / `.eslintrc.*` | Lint ルール |

### 3.4 ベストプラクティス・アンチパターン

- **Server Component を第一選択**とし、`'use client'` は必要な箇所に限定して葉側へ寄せる（バンドルサイズと初期表示の最適化）。
- **App Router では Pages Router 固有 API を使わない**（`getServerSideProps` / `getStaticProps` / `getInitialProps` は Pages Router 専用）。App Router ではサーバ側 `fetch` や Server Components 内のデータ取得を用いる。
- **`page` / `route` のないセグメントは公開されない**性質を活かし、コンポーネント・ユーティリティを `app/` 内にコロケーションしてよい（`_folder` で明示的に非ルート化も可）。
- **`error.tsx` は Client Component**（`'use client'` 必須）である点に注意する。
- App Router と Pages Router の**混在時は役割を明確化**し、同一ルートの二重定義を避ける。

## 4. 出典一覧

| 対象 | 出典 | URL |
|------|------|-----|
| Rules of React | React 公式 | <https://react.dev/reference/rules> |
| Rules of Hooks | React 公式 | <https://react.dev/reference/rules/rules-of-hooks> |
| useEffect の乱用回避 | React 公式「You Might Not Need an Effect」 | <https://react.dev/learn/you-might-not-need-an-effect> |
| コンポーネント / Hooks の基礎 | React 公式 Learn | <https://react.dev/learn> |
| App Router ファイル規約・プロジェクト構成 | Next.js 公式 | <https://nextjs.org/docs/app/getting-started/project-structure> |
| Server / Client Components | Next.js 公式 | <https://nextjs.org/docs/app/getting-started/server-and-client-components> |
| 環境変数（`NEXT_PUBLIC_`） | Next.js 公式 | <https://nextjs.org/docs/app/guides/environment-variables> |
