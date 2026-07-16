# Vue / Nuxt フレームワークプロファイル

対象言語プロファイル: [JavaScript 規約](../../skills/coding-javascript/references/conventions.md) / [TypeScript 規約](../../skills/coding-typescript/references/conventions.md)（言語規約はそちらに従う。本ファイルは FW 固有規約のみ）

準拠する主要出典:

- Vue 公式スタイルガイド <https://vuejs.org/style-guide/>（Priority A: Essential / Priority B: Strongly Recommended）
- Vue 公式「`<script setup>`」<https://vuejs.org/api/sfc-script-setup.html>
- Nuxt 公式「Directory Structure」<https://nuxt.com/docs/guide/directory-structure>
- Nuxt 公式「Data Fetching」<https://nuxt.com/docs/getting-started/data-fetching>
- Pinia 公式 <https://pinia.vuejs.org/>

（本ファイル末尾の「4. 出典一覧」に個別ページを集約）

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Vue 3 | `package.json` の dependencies に `vue`（`^3`）。`.vue`（SFC）ファイルの存在 |
| Nuxt | dependencies に `nuxt`。`nuxt.config.ts` / `nuxt.config.js`。`app/` ディレクトリ（Nuxt 4） |
| Vite + Vue | devDependencies に `@vitejs/plugin-vue`（ビルド・環境変数・テストは [frontend-tooling.md](frontend-tooling.md) を参照） |
| Pinia | dependencies に `pinia` / `@pinia/nuxt` |

このユーザの主構成: Nuxt 4 + Pinia + Tailwind の SSR テンプレート。Nuxt を厚めに扱う。

## 2. Vue 3

### 2.1 プロジェクト構造・配置規則

- **Composition API + `<script setup>` を第一選択**とする（Vue 公式「`<script setup>`」<https://vuejs.org/api/sfc-script-setup.html>。SFC で Composition API を使う際の推奨構文。ボイラープレートが少なく型推論が良好）。Options API も引き続き有効だが、新規は `<script setup>` を基本とする。
- **SFC（単一ファイルコンポーネント `.vue`）のブロック順序**は慣習として **`<script>` → `<template>` → `<style>`**（`<script setup>` を先頭に置く。Vue 公式のツール・ドキュメントで一般的な並び）。
- **1 コンポーネント 1 ファイル**（Priority B「Component files」）。

### 2.2 FW 固有の命名・実装規約

Vue 公式スタイルガイド <https://vuejs.org/style-guide/> に準拠。ルールは重要度で分類される。

**Priority A（Essential / 必須。エラー防止のため必ず守る）** — <https://vuejs.org/style-guide/rules-essential.html>:

| ルール（原文タイトル） | 内容 |
|----------------------|------|
| Use multi-word component names | コンポーネント名は**複数単語**にする（ルート `App` を除く）。既存・将来の HTML 要素との衝突を防ぐ。例: `TodoItem`（`Todo` 単語 1 つは不可） |
| Use detailed prop definitions | props は少なくとも型を含む**オブジェクト形式**で定義する（`props: ['status']` の配列形式ではなく、型・`required`・バリデータを明示） |
| Use keyed `v-for` | `v-for` には常に一意な `key` を付ける（`:key="item.id"`） |
| Avoid `v-if` with `v-for` | **同一要素に `v-if` と `v-for` を併用しない**。フィルタは computed で行い、条件描画は親要素へ `v-if` を移す |
| Use component-scoped styling | ルート `App`・レイアウト以外のコンポーネントはスタイルをスコープ化する（`<style scoped>` / CSS Modules / BEM 等） |

**Priority B（Strongly Recommended / 強く推奨。可読性・開発体験の向上）** — <https://vuejs.org/style-guide/rules-strongly-recommended.html>（原文タイトル一覧）:

- Component files（1 コンポーネント 1 ファイル）
- Single-file component filename casing（SFC ファイル名は PascalCase もしくは kebab-case で一貫させる）
- Base component names
- Tightly coupled component names
- Order of words in component names
- Self-closing components（コンテンツを持たないコンポーネントは自己閉じにする）
- Component name casing in templates（テンプレート内は PascalCase 推奨）
- Component name casing in JS/JSX
- Full-word component names
- Prop name casing（宣言は camelCase、テンプレート属性は kebab-case）
- Multi-attribute elements（属性が複数なら 1 属性 1 行）
- Simple expressions in templates
- Simple computed properties
- Quoted attribute values（属性値は常に引用符で囲む）
- Directive shorthands（`:` `@` `#` の短縮記法は使うなら一貫して使う）

その他の実装規約:

- **props / emits の型定義**: `<script setup lang="ts">` では `defineProps<T>()` / `defineEmits<T>()` の型引数で定義する（型ベース宣言）。

### 2.3 ツールチェーン

Vite + Vue を基準に記載。詳細は [frontend-tooling.md](frontend-tooling.md)。

| 用途 | コマンド | 備考 |
|------|---------|------|
| scaffold | `npm create vue@latest`（公式 `create-vue`。内部で Vite を使用） | ルータ・Pinia・Vitest 等を選択 |
| dev | `vite`（`npm run dev`） | 開発サーバ |
| build | `vite build`（`vue-tsc -b && vite build` が慣習） | 型チェック + 本番ビルド |
| preview | `vite preview` | ビルド成果物の確認 |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コード |
| `eslint.config.*`（`eslint-plugin-vue`） | Vue 向け Lint ルール |
| `tsconfig.json` | TypeScript 設定 |

### 2.4 ベストプラクティス・アンチパターン

- **`v-if` と `v-for` を同一要素で併用しない**（Priority A）。Vue 3 では `v-if` が `v-for` より優先されるため意図しない挙動になる。
- **`v-for` の `key` に配列インデックスを使わない**（並び替え・挿入削除で状態が混線する）。
- **リアクティビティの喪失に注意**: `reactive` オブジェクトを分割代入するとリアクティビティが失われる。`toRefs` / `toRef` を使うか、`ref` を用いる。
- **props を直接変更しない**（one-way data flow。変更は `emit` で親に依頼、またはローカル state / computed を介す）。
- **Composition API を第一選択**とし、Options API と混在させる場合は方針を統一する。

## 3. Nuxt

Nuxt は Vue のフルスタックフレームワーク。Nuxt 3 系（本ユーザは **Nuxt 4**）を対象とする。Nuxt 4 では既定のソースディレクトリが **`app/`** に変わった点が Nuxt 3 との大きな差分。

### 3.1 プロジェクト構造・配置規則

Nuxt 公式「Directory Structure」<https://nuxt.com/docs/guide/directory-structure> に基づく。Nuxt 4 の既定構成:

**`app/` ディレクトリ内**（アプリケーションコード。多くは自動インポート対象）:

| ディレクトリ | 役割 | 自動インポート / ルーティング |
|-------------|------|---------------------------|
| `app/pages/` | ページ | **ファイルベースルーティング**（ファイル構成が URL になる） |
| `app/components/` | Vue コンポーネント | **自動インポート**（明示 import 不要） |
| `app/composables/` | Composition 関数 | **自動インポート** |
| `app/utils/` | ユーティリティ関数 | **自動インポート** |
| `app/layouts/` | レイアウト（ページ間で再レンダーを防ぐラッパ） | `definePageMeta` / `<NuxtLayout>` で適用 |
| `app/middleware/` | ルートナビゲーションガード | 名前指定 or `global` |
| `app/plugins/` | アプリ生成時に初期化する Vue プラグイン | 自動登録 |
| `app/assets/` | ビルドツール（Vite）で処理するアセット | |
| `app/app.vue` | ルートコンポーネント | |

**プロジェクトルート**（`app/` の外側）:

| ディレクトリ / ファイル | 役割 |
|----------------------|------|
| `server/` | サーバサイドコード（`server/api/` / `server/routes/` / `server/middleware/` 等。Nitro） |
| `public/` | 無加工で配信する静的ファイル（`favicon.ico` / `robots.txt` 等） |
| `shared/` | クライアント・サーバ双方から使うコード |
| `modules/` | ローカル Nuxt モジュール |
| `content/` | Markdown ベース CMS（`@nuxt/content` モジュール使用時） |
| `nuxt.config.ts` | Nuxt 設定ファイル |
| `app.config.ts` | リアクティブな実行時設定 |

- **ページのルーティング**は `app/pages/` のファイル構成で決まる（`[id].vue` は動的ルート `:id`）。
- **自動インポート**により、`app/components/` `app/composables/` `app/utils/` は明示 import なしで利用できる。

### 3.2 FW 固有の命名・実装規約

**データ取得**（Nuxt 公式「Data Fetching」<https://nuxt.com/docs/getting-started/data-fetching>）:

| API | 用途 |
|-----|------|
| `useFetch(url)` | コンポーネントの setup で API から初期データを取得する高レベル API（`useAsyncData` + `$fetch` のラッパ）。URL ベースでキャッシュ |
| `useAsyncData(key, fn)` | 任意の非同期処理・カスタムクエリ・CMS 連携等で細かく制御したい場合。キー指定でキャッシュ |
| `$fetch(url)` | クライアント側のイベント起点の単発リクエスト（ボタン押下時の POST 等） |

- **SSR での二重取得回避**: setup 内で生の `$fetch` を使うと、サーバ（HTML 生成）とクライアント（ハイドレーション）で 2 回取得され、ハイドレーション不整合の原因になる。**setup での初期データ取得は `useFetch` / `useAsyncData` を使う**（サーバ取得データを payload 経由でクライアントへ受け渡し、再取得を防ぐ）。イベント起点の取得のみ `$fetch` を用いる。

**Pinia ストア**（Nuxt 公式推奨の状態管理。`@pinia/nuxt` モジュール。Pinia 公式 <https://pinia.vuejs.org/>）:

- ストアは `defineStore` で定義し、**`useXxxStore` 命名**にする（例: `useCartStore`。`defineStore('cart', ...)` に対して `export const useCartStore = ...`）。
- **Setup Stores 記法**（Composition API スタイル）が Nuxt との相性が良い: `state` は `ref`、`getters` は `computed`、`actions` は関数として定義し、まとめて return する。
- Nuxt では `app/stores/` 等に配置し、`@pinia/nuxt` により `useXxxStore` を自動インポートできる（設定による）。

### 3.3 ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| scaffold | `npm create nuxt@latest <name>`（公式 `create-nuxt`） | Nuxt プロジェクト生成 |
| dev | `nuxt dev`（`npm run dev`） | 開発サーバ（HMR） |
| build | `nuxt build` | SSR 向け本番ビルド（`.output/`） |
| generate | `nuxt generate` | 静的サイト生成（SSG） |
| preview | `nuxt preview` | ビルド成果物の確認 |
| 準備 | `nuxt prepare` | 型・`.nuxt/` の生成（CI 等で使用） |

- **環境変数**: 公開値は `runtimeConfig.public`（`nuxt.config.ts`）経由で `useRuntimeConfig()` から参照する。`NUXT_` プレフィクスの環境変数で上書き可能。

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `nuxt.config.ts` | Nuxt 設定（モジュール・`runtimeConfig` 等） |
| `app.config.ts` | リアクティブな実行時設定 |
| `.editorconfig` | インデント・改行・文字コード |
| `eslint.config.*`（`@nuxt/eslint`） | Nuxt 向け Lint ルール |

### 3.4 ベストプラクティス・アンチパターン

- **setup での初期データ取得に生の `$fetch` を使わない**（二重取得・ハイドレーション不整合の原因。`useFetch` / `useAsyncData` を用いる）。
- **`useAsyncData` / `useFetch` のキーを一意に保つ**（キー衝突はキャッシュ混線を招く）。
- **自動インポートを前提**にし、`app/components/` 等のコンポーネントを不要に明示 import しない（Nuxt の規約に反する冗長コード）。
- **サーバ専用コードを `server/` に隔離**し、秘匿値をクライアントバンドルに含めない（`runtimeConfig.public` のみクライアントへ露出）。
- Nuxt 4 の **`app/` ディレクトリ構成**を尊重する（Nuxt 3 のルート直下 `pages/` 等の記事をそのまま適用しない）。

## 4. 出典一覧

| 対象 | 出典 | URL |
|------|------|-----|
| スタイルガイド全体（優先度分類） | Vue 公式 | <https://vuejs.org/style-guide/> |
| Priority A（Essential） | Vue 公式 | <https://vuejs.org/style-guide/rules-essential.html> |
| Priority B（Strongly Recommended） | Vue 公式 | <https://vuejs.org/style-guide/rules-strongly-recommended.html> |
| `<script setup>` | Vue 公式 | <https://vuejs.org/api/sfc-script-setup.html> |
| ディレクトリ構造（Nuxt 4） | Nuxt 公式 | <https://nuxt.com/docs/guide/directory-structure> |
| データ取得（useFetch / useAsyncData / $fetch） | Nuxt 公式 | <https://nuxt.com/docs/getting-started/data-fetching> |
| 状態管理（Pinia） | Pinia 公式 | <https://pinia.vuejs.org/> |
