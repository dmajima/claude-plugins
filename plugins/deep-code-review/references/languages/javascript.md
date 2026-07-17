# JavaScript レビュー観点プロファイル

JavaScript コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.js` / `.mjs`（ESM 明示）/ `.cjs`（CommonJS 明示）/ `.jsx`（JSX 構文） |
| マーカーファイル | `package.json` / `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `eslint.config.js` / `.eslintrc*` / `.prettierrc*` |
| 世代判別 | `package.json` の `"type": "module"` = ESM 既定 / 無し or `"commonjs"` = CommonJS 既定 |

> `tsconfig.json` が存在する場合は TypeScript プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md`）を優先する。JavaScript と TypeScript が混在するプロジェクトでは両プロファイルを併用する。

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

JavaScript には言語公式の単一標準スタイルガイドが存在しない。プロジェクトの `.prettierrc` / `eslint.config.js` があればそれが最終的な正となり、以下は無い場合のデフォルト基準。

- Prettier デフォルト設定（フォーマット基準 / https://prettier.io/docs/options ）
- Airbnb JavaScript Style Guide（命名・慣習の代表例。Prettier デフォルトと一部差異あり）
- MDN JavaScript（言語仕様リファレンス）

## 3. レビュー観点

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] 抽象等価 `==` / `!=` による暗黙型変換バグ（`===` / `!==` を使用しているか。`x == null` で null/undefined 判定を意図する場合を除く）
- [ ] 浮動小数点誤差（`0.1 + 0.2 !== 0.3`）— 金額計算を `Number` の小数演算で行っていないか（整数最小単位・専用ライブラリの検討）
- [ ] 大整数の桁落ち（`Number.MAX_SAFE_INTEGER` 超の ID・金額を `Number` で扱っていないか → `BigInt` / 文字列保持）
- [ ] `parseInt` の基数（radix）省略（`parseInt(x, 10)`）・`parseInt` / `Number()` / 単項 `+` の使い分け
- [ ] `var` のホイスティング・関数スコープに起因するバグ（ループ内 `var` のクロージャ捕捉・宣言前参照）
- [ ] 参照共有による意図しない変更（浅いコピーと深いコピーの取り違え・オブジェクト/配列の破壊的操作）
- [ ] `NaN` の比較（`x === NaN` は常に false → `Number.isNaN`）・`typeof null === "object"` 等の落とし穴
- [ ] `Date` のタイムゾーン・パース依存（`new Date("2026-01-01")` の UTC 解釈・実装依存パース・`Date` の可変性）
- [ ] `Array.prototype.sort` の既定は辞書順（数値は `sort((a, b) => a - b)`）・`sort` / `reverse` の破壊的挙動
- [ ] `+` 演算子の型強制（`"1" + 2 === "12"`）— 数値加算と文字列連結の取り違え
- [ ] `switch` のフォールスルー（`break` / `return` 漏れによる意図しない継続実行）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] **空の catch ブロック**（`catch (e) {}` / `.catch(() => {})`）— 例外の握りつぶし
- [ ] catch して**ログのみ出力し、呼び出し元へ異常を伝えない**まま正常フローを継続していないか
- [ ] Promise の reject を握りつぶす `.catch(() => {})` / 中身のない `.catch()`（silent-failure）
- [ ] **コールバックのエラーファースト規約違反**（`(err, data) => {}` の `err` を無視・未チェックのまま続行）
- [ ] 文字列や非 Error オブジェクトを `throw` していないか（`throw new Error(...)` / サブクラスを使い、スタックトレースを保持）
- [ ] 例外の代わりに `null` / `undefined` / `false` / マジック値を返して失敗を隠蔽していないか
- [ ] `JSON.parse` / `await` / I/O 等の失敗しうる処理の未保護（try/catch or `.catch` 漏れ）
- [ ] 再スロー時に元エラーを握りつぶしていないか（`new Error(msg, { cause: err })` で原因を保持）
- [ ] `finally` 内の早期 `return` / `throw` による例外・戻り値の上書き（正常/異常フローの取り違え）

### 3.3 型・null 安全【担当: implementation-engineer】

- [ ] **`null` / `undefined` の未ガードアクセス**（`obj.a.b` で中間が undefined → `TypeError`）→ オプショナルチェーン `?.`
- [ ] `??`（Null 合体）と `||` の取り違え（`0` / `""` / `false` を意図せず既定値に置換していないか → `??`）
- [ ] 外部入力・API レスポンスの形状検証（`typeof` / スキーマ検証なしでのプロパティアクセス）
- [ ] 分割代入のデフォルト値（`const { a = [] } = opts ?? {}` で undefined 由来のエラーを防いでいるか）
- [ ] 真偽値変換の意図（falsy 値 `0` / `""` / `NaN` / `null` / `undefined` の扱いを区別しているか）
- [ ] 型判定の誤り（`typeof [] === "object"` の落とし穴 → 配列は `Array.isArray`）
- [ ] プロパティ存在確認での継承プロパティ混入（`in` / `hasOwnProperty` の使い分け → `Object.hasOwn`）
- [ ] `JSON.parse` / `JSON.stringify` ラウンドトリップでの情報欠落（`undefined` / 関数 / `Date` / `Map` / `Set`）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

- [ ] **floating promise**（`await` / `.then` / `.catch` されない Promise。`unhandledrejection` の温床・順序不定・例外消失）
- [ ] `async` 関数の戻り Promise を呼び出し側が待たずに継続していないか（fire-and-forget が意図的か）
- [ ] **`forEach` 内の `await`**（`array.forEach(async ...)` は待たれない → `for...of` / `Promise.all`）
- [ ] **`map` の戻り値（Promise 配列）の無視**（`await Promise.all(arr.map(async ...))` にすべき箇所）
- [ ] 独立した非同期処理の不要な直列 await（`await a; await b;`）→ `Promise.all` で並行化できないか
- [ ] `Promise.all`（1 件失敗で全体巻き込み）と `Promise.allSettled` の使い分けが妥当か
- [ ] 未処理の Promise reject への備え（`process.on('unhandledRejection')` / `window.onunhandledrejection`）
- [ ] 共有状態への並行更新（`await` を跨いだ read-modify-write の競合・TOCTOU）
- [ ] try/catch 内で `return await` を省略していないか（`return promise` だと同関数の catch で捕捉されない）
- [ ] トップレベル `await` / 非同期 IIFE のエラー未処理（`(async () => {})()` の reject 放置）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

- [ ] 命名規則: クラス/コンストラクタ = PascalCase、関数/変数/メソッド = camelCase、モジュールレベル定数 = UPPER_SNAKE_CASE、ファイル名 = kebab-case または camelCase（プロジェクト内で統一。React コンポーネントは PascalCase）
- [ ] 変数宣言: `const` 第一選択・再代入時のみ `let`・`var` 不使用（`no-var`）
- [ ] Prettier 整合: インデント スペース 2・末尾セミコロン・末尾カンマ・引用符（`.prettierrc` があればそれに従う）
- [ ] モジュール形式の一貫性（ESM `import`/`export` と CommonJS `require`/`module.exports` の混在。`.mjs`/`.cjs` の適切な使用）
- [ ] テンプレートリテラル・分割代入・アロー関数等モダンイディオムとの整合（既存コードのスタイルを優先）
- [ ] 未使用変数・未使用 import の残留（`no-unused-vars`）
- [ ] エクスポート形式の一貫性（default export と named export の混在方針・再エクスポートの整理）
- [ ] セミコロン自動挿入（ASI）に依存した記述（`return` 直後の改行・行頭 `(` / `[` での意図しない連結）

### 3.6 パフォーマンス【担当: performance-reviewer】

- [ ] ループ内での同期 I/O・DB 呼び出し・`await` 直列実行（N+1。node.md 参照）
- [ ] **イベントリスナー・タイマー・購読の解除漏れ**（`addEventListener` / `setInterval` / `subscribe` のクリーンアップ漏れ → メモリリーク）
- [ ] 大量データの一括メモリ展開（ストリーミング・ページング・`for await...of` の検討）
- [ ] 高頻度パスでの不要なオブジェクト/クロージャ確保・正規表現の都度コンパイル
- [ ] `map` / `filter` の多段チェーンによる中間配列の多重生成（大量データ時の削減）
- [ ] DOM 操作の反復によるレイアウトスラッシング（バッチ化・`DocumentFragment` の検討。フロントエンドは frameworks 参照）
- [ ] クロージャによる大きなオブジェクト・DOM 参照の意図しない保持（GC されずメモリ滞留）
- [ ] `reduce` 内スプレッドによる O(n^2)（`[...acc, x]` / `{...acc}` の反復。`push` / `Object.assign` / `Map` で回避）
- [ ] 大きな同期処理（巨大 `JSON.parse` / 暗号化 / 圧縮）によるイベントループブロッキング（Node）

### 3.7 セキュリティ【担当: security-engineer】

- [ ] **`innerHTML` / `outerHTML` / `document.write` へのユーザー入力代入**（XSS → `textContent` / サニタイズ）
- [ ] **`eval` / `new Function` / 文字列を渡す `setTimeout` / `setInterval`**（コードインジェクション）
- [ ] **プロトタイプ汚染**（信頼できない入力を `Object.assign` / スプレッド / 再帰マージで取り込む際の `__proto__` / `constructor` / `prototype` キー）
- [ ] SQL / NoSQL / OS コマンドの文字列連結（インジェクション → パラメタライズ / エスケープ。node.md 参照）
- [ ] 機密情報（API キー・トークン・接続文字列）のハードコード・ログ出力・クライアントバンドルへの混入
- [ ] 乱数に `Math.random()` を使用（セキュリティ用途は `crypto.getRandomValues` / `crypto.randomUUID`）
- [ ] 正規表現の ReDoS（ユーザー入力に対するカタストロフィックバックトラッキング）
- [ ] `postMessage` の `origin` 未検証・送信側の `targetOrigin` に `"*"` を使用（クロスオリジンリーク）
- [ ] オープンリダイレクト（ユーザー入力の URL を検証せず `location.href` / リダイレクト先に使用）
- [ ] `target="_blank"` のリンクに `rel="noopener noreferrer"` 欠落（リバースタブナビング）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] JSDoc（`@param` / `@returns` / `@throws`）とシグネチャ・実装の不一致（引数名・型・戻り値・例外）
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコード・デバッグ用 `console.log` の残留

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| `innerHTML` 等へのユーザー入力代入 | Critical | XSS |
| `eval` / `new Function` へのユーザー入力 | Critical | コードインジェクション |
| SQL / コマンド文字列連結（ユーザー入力含む） | Critical | インジェクション |
| プロトタイプ汚染（信頼できない入力のマージ） | High〜Critical | 改ざん・権限昇格 |
| floating promise（await / .catch 漏れ） | High | 例外消失・順序不定・プロセス停止 |
| 空 catch / `.catch(() => {})` による握りつぶし | High | 障害の無言化・調査不能化 |
| コールバックの `err` 無視 | High | 失敗の見逃し |
| null / undefined ガード漏れ（外部入力） | High | `TypeError` で機能停止 |
| `forEach` 内 await（待たれない） | Medium〜High | 完了前に後続実行・データ不整合 |
| 金額 / 大整数を `Number` で計算 | Medium〜High | 精度欠落・桁落ち |
| イベントリスナー解除漏れ | Medium〜High | メモリリーク（長時間稼働で顕在化） |
| ループ内同期 I/O・直列 await | Medium〜High | 性能劣化（データ量依存） |
| 正規表現の ReDoS（脆弱なパターン＋ユーザー入力） | Medium〜High | サービス停止 |
| `==` 抽象等価による型強制 | Medium | 予期しない比較結果 |
| `Date` / タイムゾーン・パース依存 | Medium | 日付ずれ・境界バグ |
| `reduce` 内スプレッド（O(n^2)） | Medium | 大量データで性能劣化 |
| `var` 使用・命名規則違反 | Medium〜Low | 巻き上げバグ誘発・可読性・規約整合 |
| Prettier 未整形・未使用変数 | Low | スタイル整合 |

### NG / OK 例（floating promise + silent-failure）

```javascript
// NG: Promise を await/return せず、失敗も握りつぶす（floating promise + silent-failure）
function saveOrder(order) {
  repo.save(order).catch(() => {}); // 失敗が無言で消え、呼び出し元は成功と誤認
}

// OK: 呼び出し元へ完了と失敗を伝える
async function saveOrder(order) {
  try {
    await repo.save(order);
  } catch (err) {
    throw new OrderSaveError(`注文 ${order.id} の保存に失敗`, { cause: err });
  }
}
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| `express` / `@nestjs/*` / Node.js サーバーコード | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/node.md` |
| `react` / `next` | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| `vue` / `nuxt` | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| `vite` / `jest` / `vitest` / `@playwright/*` 等（フロントエンドツール） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| 構文チェック | `node --check <file>` | エラー = 強制 FAIL（Critical〜High） |
| Lint | `npx eslint <path>` | error = High〜Medium / warning = Medium〜Low |
| フォーマット | `npx prettier --check <path>` | 差分あり = Low〜Medium |
| テスト（Vitest） | `npx vitest run` | 失敗 1 件ごとに最低 High |
| テスト（Jest） | `npx jest` | 同上 |
| テスト（Node 標準） | `node --test` | 同上 |
