# Vue / Nuxt レビュー観点プロファイル

Vue 3 / Nuxt の変更差分をレビューする際の FW 固有観点。JavaScript / TypeScript の言語共通観点は各言語プロファイルに従い、本ファイルは FW 固有観点のみを扱う。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

準拠する主要出典（プロジェクト独自規約が無い場合のデフォルト基準）:

- Vue 公式スタイルガイド <https://vuejs.org/style-guide/>
- Vue「`<script setup>`」<https://vuejs.org/api/sfc-script-setup.html>
- Nuxt「Data Fetching」<https://nuxt.com/docs/getting-started/data-fetching>
- Pinia 公式 <https://pinia.vuejs.org/>

## 1. 対象と検出条件

| フレームワーク | 検出条件 |
|--------------|---------|
| Vue 3 | `package.json` の dependencies に `vue`（`"^3..."`）。`.vue`（SFC）ファイルの存在 |
| Nuxt | dependencies に `nuxt`。`nuxt.config.ts` / `.js`。Nuxt 4 は既定ソースが `app/` ディレクトリ |
| Vite + Vue | devDependencies に `@vitejs/plugin-vue` |
| Pinia | dependencies に `pinia` / `@pinia/nuxt` |

## 2. レビュー観点

### 2.1 Vue 3

#### 2.1.1 リアクティビティ【担当: implementation-engineer】

- [ ] **`reactive` オブジェクトを分割代入してリアクティビティを失っていないか**（`const { count } = reactive(...)` は追跡が切れる。`toRefs` / `toRef` を使うか `ref` を用いる）
- [ ] `ref` と `reactive` の使い分けが適切か（プリミティブは `ref`、`.value` アクセス漏れがないか）
- [ ] `computed`（派生値・キャッシュあり）と `watch`（副作用）を用途で使い分けているか。computed 内で副作用（API 呼び出し・state 変更）を起こしていないか
- [ ] `watchEffect` の依存が意図通りか（自動追跡される依存の範囲を理解しているか。明示依存が必要なら `watch` を使う）
- [ ] ライフサイクル・`watch` で登録した購読・タイマー・イベントリスナーを `onUnmounted` 等で解除しているか
- [ ] 大きな不変データや外部インスタンスに深いリアクティブ変換を掛けていないか（`shallowRef` / `shallowReactive` / `markRaw` を検討する）
- [ ] `watch` の `deep` / `immediate` が必要箇所で指定され、逆に不要な `deep` で大きなオブジェクトを常時走査していないか

#### 2.1.2 テンプレート・コンポーネント規約【担当: implementation-engineer】

- [ ] **props を子で直接変更していないか**（one-way data flow。変更は `emit` で親に依頼、またはローカル state / computed を介す）
- [ ] `v-for` に一意な `key` を付けているか。並び替え・挿入削除がある場合に配列インデックスを key にしていないか（状態混線）
- [ ] **同一要素で `v-if` と `v-for` を併用していないか**（Vue 3 は `v-if` が優先。フィルタは computed で行い、条件描画は親要素へ `v-if` を移す）
- [ ] コンポーネント名が複数単語か（ルート `App` を除く。既存・将来の HTML 要素との衝突防止）
- [ ] template 内の複雑な式を computed に切り出しているか（テンプレートは宣言的に保つ）
- [ ] `defineProps` / `defineEmits` の型引数と実使用（未使用 prop・未宣言 emit の発火）が一致しているか
- [ ] カスタムコンポーネントの `v-model` が `defineModel` または `modelValue` + `update:modelValue` の規約に沿っているか
- [ ] `<script setup lang="ts">` で `defineProps<T>()` / `defineEmits<T>()` の型ベース宣言を使っているか
- [ ] コンテンツを持たないコンポーネントを自己閉じ（`<MyComp />`）にし、複数属性の要素を 1 属性 1 行にしているか（スタイルガイド Priority B）
- [ ] props 宣言は camelCase・テンプレート属性は kebab-case で一貫し、属性値を常に引用符で囲んでいるか（Priority B）

#### 2.1.3 セキュリティ・スタイル【担当: security-engineer / web-designer】

- [ ] `v-html` にサニタイズなしのユーザー入力を渡していないか（XSS。必要時は `DOMPurify` 等でサニタイズ）
- [ ] ルート `App`・レイアウト以外のコンポーネントで `<style scoped>` / CSS Modules 等のスコープ化をしているか（グローバルへのスタイル漏れ）
- [ ] `v-bind` でユーザー入力を `href` / `src` に渡す際、`javascript:` 等の危険なスキームを許容していないか
- [ ] `target="_blank"` のリンクに `rel="noopener"` を付与しているか（tabnabbing 防止）

### 2.2 Nuxt

#### 2.2.1 データ取得【担当: implementation-engineer / performance-reviewer】

- [ ] **setup での初期データ取得に生の `$fetch` を使っていないか**（サーバ（HTML 生成）とクライアント（ハイドレーション）で二重取得され不整合を招く。`useFetch` / `useAsyncData` を使う）
- [ ] `useFetch` / `useAsyncData` のキーが一意か（キー衝突はキャッシュ混線を招く）
- [ ] イベント起点の単発リクエスト（ボタン押下時の POST 等）にのみ `$fetch` を使っているか（使い分け）
- [ ] `useAsyncData` / `useFetch` で必要なフィールドのみ `pick` / `transform` し、ペイロードを不要に肥大化させていないか

#### 2.2.2 SSR 状態管理【担当: implementation-engineer / security-engineer】

- [ ] **モジュールスコープ変数（`.ts` / `.js` トップレベルの `let` やオブジェクト）でユーザー状態を保持していないか**（SSR サーバは全リクエストで同一インスタンスを共有するため、リクエスト間で他ユーザーのデータが漏れる。状態は `useState` / Pinia で持つ）
- [ ] `useState` のキーが一意で、リクエストスコープに正しく閉じているか
- [ ] `useState` の初期化を関数で渡し（`useState("k", () => ...)`）、初期値にモジュールスコープの可変オブジェクトを共有していないか
- [ ] Pinia ストアを `useXxxStore` 命名（`defineStore` + Setup Stores 記法）で定義し、SSR で正しく初期化しているか

#### 2.2.3 サーバルート・設定【担当: security-engineer】

- [ ] `server/api`・`server/routes`（Nitro）の入力検証を行っているか（クライアント側検証だけに依存していないか）
- [ ] **`runtimeConfig` で公開値（`public`）と秘密値を区別し、秘密をクライアントバンドルに露出していないか**（`public` 以外はサーバ専用。最重要）
- [ ] サーバ専用コード・秘密参照を `server/` に隔離しているか
- [ ] `server/api` のレスポンスに内部エラー詳細（スタックトレース・DB エラー）をそのまま返していないか

#### 2.2.4 ミドルウェア・構造【担当: implementation-engineer】

- [ ] ルートミドルウェアの実行順・グローバル / 名前付きの区別が意図通りか
- [ ] Nuxt 4 の `app/` ディレクトリ構成を尊重しているか（Nuxt 3 のルート直下 `pages/` 等の記述をそのまま持ち込んでいないか）
- [ ] 自動インポート対象（`app/components` / `app/composables` / `app/utils`）を冗長に明示 import していないか
- [ ] ビルド時設定（`nuxt.config.ts`）と実行時リアクティブ設定（`app.config.ts`）を用途で使い分けているか

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| モジュールスコープでのユーザー状態保持（SSR リクエスト間リーク） | Critical | 他ユーザーへの情報漏洩 |
| `runtimeConfig` の秘密値のクライアント露出・秘密のハードコード | Critical | 秘密情報漏洩 |
| `v-html` に未サニタイズ入力 | Critical〜High | XSS |
| `server/api` の入力検証欠如 | High | インジェクション・不正操作 |
| props の直接変更 | High〜Medium | データフロー破綻・予期しない副作用 |
| setup での生 `$fetch`（二重取得・ハイドレーション不整合） | Medium〜High | 不整合・過負荷 |
| `reactive` 分割代入によるリアクティビティ喪失 | Medium〜High | UI が更新されないバグ |
| 購読・タイマーの解除漏れ | Medium | メモリリーク |
| `v-if` と `v-for` の同一要素併用 | Medium | 意図しない挙動・無駄な評価 |
| `v-for` の key 欠落 / index key 誤用 | Medium | 状態混線・描画バグ |
| `useFetch` / `useAsyncData` のキー衝突 | Medium | キャッシュ混線 |
| `server/api` の内部エラー詳細の露出 | Medium〜High | 情報漏洩 |
| 大規模データの過剰リアクティブ化（shallow 未使用） | Low〜Medium | 性能 |
| computed / watch の誤用・template 内の複雑な式 | Low〜Medium | 可読性・性能 |
| コンポーネント単一単語名・スタイル未スコープ | Low | 規約・スタイル漏れ |

### NG / OK 例（SSR でのモジュールスコープ状態）

```ts
// NG: モジュールスコープの変数が全リクエストで共有され、他ユーザーのデータが漏れる
let currentUser: User | null = null; // サーバでは単一インスタンス
export function useCurrentUser() {
  return { currentUser };
}

// OK: useState でリクエストスコープに閉じる（SSR 安全・payload でクライアントへ受け渡し）
export function useCurrentUser() {
  return useState<User | null>("currentUser", () => null);
}
```

## 4. 関連プロファイル参照

差分に以下が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| Nuxt サーバルート（Nitro）・Node.js ツールチェーン | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/node.md` |
| TypeScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md` |
| JavaScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/javascript.md` |
| HTML / CSS・アクセシビリティ観点 | `${CLAUDE_PLUGIN_ROOT}/references/languages/html.md` |
