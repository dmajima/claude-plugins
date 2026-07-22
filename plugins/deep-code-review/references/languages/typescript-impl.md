# TypeScript レビュー観点プロファイル — impl details

`typescript.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `typescript.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.4 3.5 3.6 3.8 を収録。

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] 外部入力（API レスポンス・`JSON.parse` の結果・フォーム値・環境変数）をコンパイル時の型だけで信頼していないか（型は実行時を保証しない。ランタイム検証は 3.3 参照）
- [ ] `strictNullChecks` 下で `undefined` / `null` の可能性を無視した参照がないか（オプショナルチェーン `?.` / 存在チェック / 初期値付与）
- [ ] 判別可能ユニオンの分岐網羅（`switch` で全ケース処理・`never` 型による網羅性チェック・default 漏れ）
- [ ] 数値 enum の暗黙値・逆マッピングに依存していないか（メンバー追加・並び替えで壊れる）
- [ ] 配列/オブジェクトアクセス `arr[i]` を `noUncheckedIndexedAccess` 無効前提で `undefined` を含まないものとして扱っていないか
- [ ] 型定義（`.d.ts` / 型注釈）と実際のランタイム値・シリアライズ結果の乖離がないか
- [ ] 非 JSON 値（`Date` / `Map` / `Set` / `bigint` / `undefined`）を `JSON.stringify` 経由で受け渡す箇所で、型注釈が欠落・変質を反映しているか

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] `catch (e)` の `e` を `any` 扱いで無検証にプロパティアクセスしていないか（`useUnknownInCatchVariables` 前提で `unknown` として型を絞る）
- [ ] **空 catch・ログのみ**で呼び出し元へ異常を伝えないまま正常フローを継続していないか（JavaScript プロファイル継承）
- [ ] Promise の reject を握りつぶしていないか（`.catch(() => {})` の空実装・await 漏れによる未処理 rejection は 3.4）
- [ ] 失敗を `null` / `undefined` / 例外の代わりに返す際、戻り値型がそれを明示しているか（`T | null` を `T` と偽って返していないか）
- [ ] 型アサーション（`as`）でエラー型・不整合をコンパイルだけ通して握りつぶしていないか
- [ ] 失敗表現（例外 / Result 型・`{ ok: false }` 等の判別可能ユニオン）がモジュール内で一貫しているか
- [ ] **リファクタで既存の防御コードが削除されていないか（U16 回帰検出）**: 差分の削除側でベースの `try/catch`・`.catch()`・エラー state・型定義（`any` 化による型消失）が失われていれば回帰として指摘する（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16）

### 3.3 型設計・型安全【担当: implementation-engineer】

- [ ] **`any` の濫用** — 型が不明な値は `unknown` + 型ガードで絞り込む。暗黙 any（`noImplicitAny` 無効・引数の型注釈漏れ TS7006）を放置していないか
- [ ] **`as` 型アサーションの濫用** — 型システムの迂回。特に二重アサーション `as unknown as X` は型安全性を完全に無効化するため原則禁止
- [ ] **`!` non-null assertion の安易な使用** — 実行時 `undefined` 参照で例外。存在保証がある箇所に限定し、可能なら型ガード・早期 return へ置換
- [ ] `@ts-ignore` / `@ts-expect-error` の濫用 — 理由コメント必須。抑制範囲が広い `@ts-ignore` より原因を局所化する `@ts-expect-error` を優先
- [ ] `strict`（`strictNullChecks` / `noImplicitAny` 等）が `tsconfig.json` / インラインで個別に無効化されていないか
- [ ] ユーザー定義型ガード（`x is T`）・判別可能ユニオンで安全に絞り込んでいるか（型アサーションで代替していないか）
- [ ] **インターフェースに `I` プレフィクスを付けていないか**（`IUser` ではなく `User`。**C# とは逆**の慣習である点に注意）。型名に `Type` / `Interface` 接尾辞も付けない
- [ ] `interface` と `type` の使い分けがプロジェクト内で一貫しているか
- [ ] `import type` / `export type`（型のみインポート）を使い分けているか — `verbatimModuleSyntax` / `isolatedModules` 下では値と型の混在が不要な実行時 import・ビルドエラーを生む
- [ ] 型を手書きで二重管理していないか — 定数オブジェクト・既存型から `keyof` / `typeof` / インデックスアクセス型で導出し、単一の正を保つ
- [ ] `enum` と union 型（`as const` 由来のリテラルユニオン含む）の選択が適切か（型のみ用途・tree-shaking を要する場面では union 優先の判断）
- [ ] `satisfies` 演算子でリテラル型推論を保ちつつ制約を掛けるべき箇所を、`as` や広い明示注釈で推論を潰していないか
- [ ] **外部入力のランタイム検証欠落** — API レスポンス・`JSON.parse`・環境変数を `zod` / `valibot` 等で検証し `z.infer` で型導出しているか（型アサーションだけでは実行時に守られない）
- [ ] ジェネリクスの過不足 — 不要なジェネリクス化 / 本来ジェネリクスにすべき箇所を `any` で済ませていないか。型パラメータは意味的に命名（`TKey` / `TValue`）
- [ ] 公開 API（エクスポート関数・メソッド）の戻り値型が明示されているか。型の広がり（literal であるべき値が `string` に広がる等）
- [ ] プリミティブラッパー型（`String` / `Number` / `Boolean` / `Object`）を型注釈に使っていないか（小文字の `string` / `number` 等を使う）
- [ ] 過度に広い型（`{}` は null/undefined 以外の任意値・`object` / `Function`）で実質的な型チェックを失っていないか
- [ ] 構造的型付けの余剰プロパティチェックに依存していないか（オブジェクトリテラル直接渡しでのみ検出され、変数経由では余剰プロパティが素通りする）
- [ ] 不変性 — 変更しない配列・オブジェクトに `readonly` / `readonly T[]` / `as const` が活用されているか

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

- [ ] **await 漏れ（floating promise）** — Promise を返す式を await / return / void 化せず放置していないか（`@typescript-eslint/no-floating-promises`）。fire-and-forget が意図的か（JavaScript プロファイル継承を型情報で強化）
- [ ] **`Promise<void>` の誤用** — `() => void` を期待するコールバックに async 関数を渡し、返る Promise の reject が捨てられていないか（`@typescript-eslint/no-misused-promises`）
- [ ] 非同期の戻り値を同期的に型付けしていないか（`Promise<T>` を `as T` で剥がす / await 忘れで `Promise<T>` のままプロパティアクセス）
- [ ] 公開 async 関数の戻り値型が `Promise<T>` として明示されているか
- [ ] 独立した非同期処理の逐次 await（`Promise.all` での並行化。JavaScript プロファイル継承）
- [ ] キャンセル・タイムアウト（`AbortController` / `AbortSignal`）の型付き伝搬漏れ（長時間 I/O・ループ処理）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

- [ ] 型エイリアス / インターフェース / enum / 列挙メンバー = PascalCase
- [ ] **インターフェースに `I` プレフィクスを付けない**（C# と逆。3.3 の再掲だが命名規約として確認）
- [ ] ジェネリクス型パラメータ = `T` 起点の簡潔名、または意味のある PascalCase（`TKey` / `TValue`）
- [ ] 変数・関数・定数の命名（camelCase 等）は JavaScript プロファイルを継承
- [ ] Prettier デフォルト整形（JavaScript プロファイルと共通。`.prettierrc` / `.editorconfig` があれば優先）
- [ ] `interface` / `type` の一貫性・型定義の配置（既存コードのスタイルを優先）

### 3.6 パフォーマンス【担当: performance-reviewer】

- [ ] JavaScript プロファイルのパフォーマンス観点（ループ内 I/O・N+1・不要な再計算・大量データ全件展開）をすべて継承
- [ ] 数値 enum（`const` でないもの）が生成する実行時オブジェクトのコスト（型のみ用途なら `as const` union の検討。`const enum` は `isolatedModules` と非互換な点に注意）
- [ ] 過度な型計算（巨大な条件型・深い再帰型）による `tsc` の型チェック性能劣化（ビルド時間・IDE 応答）
- [ ] バレルファイル（`index.ts` の再エクスポート集約）による tree-shaking 阻害・循環参照
- [ ] 型アサーションで隠された不要なコピー・変換処理

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] TSDoc / JSDoc（`@param` / `@returns`）と型注釈・シグネチャの不一致（型は TS が正。コメント側の型記述は冗長で乖離しやすい）
- [ ] `@deprecated` 注記と実際の使用箇所・代替 API の整合
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] `@ts-expect-error` / `@ts-ignore` の理由コメント欠落（3.3 と連動）
- [ ] コメントアウトされたコード・未使用型定義の残留

