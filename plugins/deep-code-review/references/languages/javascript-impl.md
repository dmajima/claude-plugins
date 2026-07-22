# JavaScript レビュー観点プロファイル — impl details

`javascript.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `javascript.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.4 3.5 3.6 3.8 を収録。

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

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] JSDoc（`@param` / `@returns` / `@throws`）とシグネチャ・実装の不一致（引数名・型・戻り値・例外）
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコード・デバッグ用 `console.log` の残留

