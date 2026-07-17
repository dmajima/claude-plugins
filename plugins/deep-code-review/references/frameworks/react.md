# React / Next.js レビュー観点プロファイル

React / Next.js の変更差分をレビューする際の FW 固有観点。JavaScript / TypeScript の言語共通観点は各言語プロファイルに従い、本ファイルは FW 固有観点のみを扱う。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

準拠する主要出典（プロジェクト独自規約が無い場合のデフォルト基準）:

- React「Rules of Hooks」<https://react.dev/reference/rules/rules-of-hooks>
- React「You Might Not Need an Effect」<https://react.dev/learn/you-might-not-need-an-effect>
- Next.js「Server and Client Components」<https://nextjs.org/docs/app/getting-started/server-and-client-components>
- Next.js「Environment Variables」<https://nextjs.org/docs/app/guides/environment-variables>

## 1. 対象と検出条件

| フレームワーク | 検出条件 |
|--------------|---------|
| React | `package.json` の dependencies に `react` / `react-dom`。`.jsx` / `.tsx` ファイルの存在 |
| Next.js | dependencies に `next`。`next.config.js` / `.ts` / `.mjs`。`app/`（App Router）または `pages/`（Pages Router）ディレクトリ |
| Vite + React | devDependencies に `@vitejs/plugin-react`（ビルド・環境変数は言語プロファイル側で扱う） |

## 2. レビュー観点

### 2.1 React

#### 2.1.1 Hooks のルール【担当: implementation-engineer】

- [ ] Hooks を React 関数のトップレベルで呼んでいるか（**条件分岐・ループ・ネストした関数・早期 return より後**で呼んでいないか。呼び出し順が変動するとフックの対応が破綻する）
- [ ] Hooks を関数コンポーネントまたはカスタムフックからのみ呼んでいるか（通常の JS 関数から呼んでいないか）
- [ ] useEffect の依存配列に過不足がないか（`exhaustive-deps`。Effect 内で参照する reactive 値を全列挙し、意図的省略のために配列を偽っていないか）
- [ ] useEffect のクリーンアップ漏れがないか（イベント購読・タイマー・WebSocket・`AbortController` の解除を return 関数で行っているか）
- [ ] **リファクタ前後で防御コードが保持されているか（U16 回帰検出）**: 差分でベースに存在した error state 表示（`role="alert"` 等）・エラーハンドリング（`try/catch` / `.catch()`）・クリーンアップ（`AbortController` / return 関数）・依存配列が削除されていないか。削除されていれば回帰として指摘する（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16）
- [ ] カスタムフックが `use` プレフィクスで命名され、その内部の Hook 呼び出しも条件分岐・早期 return の影響下に入っていないか

#### 2.1.2 useEffect の濫用・状態設計【担当: implementation-engineer】

- [ ] props / state から算出できる派生値を useEffect + setState で同期していないか（**レンダー中に計算**する。重い場合のみ `useMemo`）
- [ ] ユーザーイベント起点の処理を useEffect ではなくイベントハンドラ（`onClick` 等）で行っているか
- [ ] state / props を直接ミューテートしていないか（新しいオブジェクト・配列を生成して更新しているか）
- [ ] state のリフトアップが過剰でないか / props drilling が深すぎないか（context・コンポーネント合成の検討）
- [ ] 制御コンポーネントと非制御コンポーネントが混在していないか（`value` と `defaultValue` の同時指定等）
- [ ] レンダーに影響しない可変値（前回値・DOM 参照・タイマー ID）を state ではなく `useRef` で保持しているか

#### 2.1.3 レンダリング・key【担当: performance-reviewer】

- [ ] リストの `key` が欠落していないか。**並び替え・挿入削除がある場合に配列インデックスを key にしていないか**（差分計算が破綻し state が混線する）
- [ ] 不要な再レンダーを誘発していないか（毎レンダーでのオブジェクト・関数・配列生成を子へ props 渡し）。必要な箇所で `memo` / `useMemo` / `useCallback` を用い、かつ効果の薄い過剰な memo 化をしていないか（両面を評価する）
- [ ] コンポーネントを関数として直接呼んでいないか（`MyComponent()` ではなく `<MyComponent />` で使う）
- [ ] 数百件以上の大きなリストを一括描画していないか（仮想化（`react-window` 等）・ページング・無限スクロールを検討する）

#### 2.1.4 セキュリティ【担当: security-engineer / web-designer】

- [ ] `dangerouslySetInnerHTML` にサニタイズなしのユーザー入力を渡していないか（XSS。必要時は `DOMPurify` 等でサニタイズ）
- [ ] `href` / `src` 等の URL 属性に `javascript:` を許容するユーザー入力を渡していないか
- [ ] `target="_blank"` のリンクに `rel="noopener"` を付与しているか（`window.opener` 経由の tabnabbing 防止）

### 2.2 Next.js

#### 2.2.1 Server / Client Components 境界【担当: implementation-engineer】

- [ ] `'use client'` がツリーの**葉側**に置かれ、Client 境界が不必要に広がっていないか（バンドル増大・初期表示劣化）
- [ ] Server Component から Client Component へ関数・クラスインスタンス等シリアライズ不可能な props を渡していないか
- [ ] `error.tsx` が Client Component（`'use client'` 必須）になっているか
- [ ] App Router で Pages Router 専用 API（`getServerSideProps` / `getStaticProps` / `getInitialProps`）を使っていないか

#### 2.2.2 データ取得・ルーティング【担当: implementation-engineer / performance-reviewer】

- [ ] `fetch` のキャッシュ制御（`cache` / `next: { revalidate }`）が意図通りか（過剰キャッシュによる古いデータ表示・キャッシュ漏れによる過負荷）
- [ ] Route Handler（`route.ts`）で正しい HTTP メソッド関数（`GET` / `POST` 等）を export しているか
- [ ] `page` / `route` の無いセグメントを公開ルートと誤認していないか
- [ ] `metadata` エクスポートまたは `generateMetadata` を適切に定義しているか
- [ ] `loading.tsx` / `Suspense` 境界と `error.tsx` 境界が適切な粒度で配置され、待ち時間・失敗を局所化しているか

#### 2.2.3 環境変数・機密【担当: security-engineer】

- [ ] **サーバ専用の秘密情報に `NEXT_PUBLIC_` プレフィクスを付けてクライアントバンドルへ露出していないか**（付与するとブラウザに埋め込まれる。最重要）
- [ ] Server Action（`'use server'`）で入力検証・認可（呼び出し元の権限確認）を行っているか
- [ ] クライアントコンポーネントから DB・秘密鍵へ直接アクセスしていないか（Route Handler / Server Action 経由にする）

#### 2.2.4 画像・リンク・ハイドレーション【担当: web-designer / implementation-engineer】

- [ ] `next/image` / `next/link` を適切に使っているか（生 `<img>` / `<a>` による画像最適化・プリフェッチの喪失）
- [ ] ハイドレーションミスマッチを招く実装がないか（サーバ / クライアントで初期出力が異なる: `Date.now()` / `Math.random()` / `window` 参照 / ロケール依存の日時・数値整形を初期レンダーで使用）

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| `NEXT_PUBLIC_` でないシークレットのクライアント露出 | Critical | 秘密情報がバンドルに混入し漏洩 |
| `dangerouslySetInnerHTML` に未サニタイズ入力 | Critical〜High | XSS |
| Hooks を条件分岐 / ループ内で呼ぶ | High | フック順序破綻・実行時エラー |
| カスタムフック内の Hook 呼び出しを条件分岐配下に配置 | High | Rules of Hooks 違反 |
| Server → Client への非シリアライズ props | High | 実行時エラー |
| Pages Router 専用 API を App Router で使用 | High | 動作しない |
| Server Action の入力検証・認可漏れ | High | 不正操作・権限昇格 |
| useEffect クリーンアップ漏れ（購読・タイマー） | High〜Medium | メモリリーク・多重購読 |
| useEffect 依存配列の偽り（意図的省略） | High〜Medium | 古い値参照・更新漏れ |
| state / props の直接ミューテート | High〜Medium | 再レンダー不発・不整合 |
| ハイドレーションミスマッチ | Medium〜High | 描画不整合・警告 |
| リスト key 欠落 / index key 誤用 | Medium | 状態混線・描画バグ |
| fetch キャッシュ制御の誤り | Medium | 古いデータ表示・過負荷 |
| useEffect による派生値同期（不要 Effect） | Medium | 冗長な再レンダー・バグ源 |
| 不要な再レンダー / 過剰な memo 化 | Low〜Medium | 性能・可読性 |
| 生 `<img>` / `<a>` による最適化喪失 | Low〜Medium | 表示性能・体験劣化 |
| `target="_blank"` の `rel="noopener"` 欠落 | Low〜Medium | tabnabbing |

### NG / OK 例（派生値の Effect 同期）

```jsx
// NG: props から算出できる値を Effect + state で同期（不要な Effect・二重レンダー）
function FullName({ firstName, lastName }) {
  const [fullName, setFullName] = useState("");
  useEffect(() => { setFullName(`${firstName} ${lastName}`); }, [firstName, lastName]);
  return <p>{fullName}</p>;
}

// OK: レンダー中に計算する（Effect も state も不要）
function FullName({ firstName, lastName }) {
  const fullName = `${firstName} ${lastName}`;
  return <p>{fullName}</p>;
}
```

## 4. 関連プロファイル参照

差分に以下が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| 同一リポジトリのバックエンドが Node.js（Express / NestJS） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/node.md` |
| TypeScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md` |
| JavaScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/javascript.md` |
| HTML / CSS・アクセシビリティ観点 | `${CLAUDE_PLUGIN_ROOT}/references/languages/html.md` |
