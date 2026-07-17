# Node.js サーバーフレームワーク レビュー観点プロファイル

Node.js 製サーバー（Express 5 / NestJS）の変更差分をレビューする際の FW 固有観点。JavaScript / TypeScript の言語共通観点は各言語プロファイルに従い、本ファイルは FW 固有観点のみを扱う。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

準拠する主要出典（プロジェクト独自規約が無い場合のデフォルト基準）:

- Express 移行ガイド（4 → 5） <https://expressjs.com/en/guide/migrating-5.html>
- Express セキュリティのベストプラクティス <https://expressjs.com/en/advanced/best-practice-security.html>
- NestJS 公式ドキュメント <https://docs.nestjs.com/>

## 1. 対象と検出条件

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.js` / `.mjs` / `.cjs` / `.ts` |
| フレームワーク検出 | 下表の依存名で判定する |

| フレームワーク | 検出条件（`package.json` の dependencies） |
|--------------|-------------------------------------------|
| Express 5 | `express`（`"^5..."`）。4 系と 5 系はバージョンで判別する（async 自動伝播の有無が変わるため世代の確定が必須） |
| NestJS | `@nestjs/core` / `@nestjs/common`、プロジェクトルートに `nest-cli.json` |

## 2. レビュー観点

### 2.1 Express 5

#### 2.1.1 ルーティング・ミドルウェア構造【担当: implementation-engineer】

- [ ] エラーハンドリングミドルウェアが 4 引数シグネチャ `(err, req, res, next)` で定義され、**全ルーター登録の後（最後）** に `app.use()` されているか（引数が 3 つだと通常ミドルウェア扱いになりエラーを捕捉できない）
- [ ] ルート登録順序が適切か（限定的なパスを先に、ワイルドカード・catch-all を後に置いているか）
- [ ] ミドルウェアで `next()` の呼び忘れがないか（リクエストがハングする）。逆に `next()` 後に処理を継続していないか
- [ ] Express 4 → 5 の廃止 API を使っていないか（`app.del` → `app.delete`、`req.param()` → `req.params` / `req.query` / `req.body`、無名ワイルドカード `/*` → 名前付き `/*splat`）
- [ ] Router / Controller / Service が分離され、Service 層に `req` / `res` が漏れていないか

#### 2.1.2 async エラー処理・レスポンス整合【担当: implementation-engineer】

- [ ] Express 5 の async 自動伝播（Promise reject 時に自動 `next(err)`）を前提とするか、v4 互換の `try/catch` + `next(err)` を明示するかが混在して意図がぶれていないか。**v4 前提コードで async ハンドラの reject を握りつぶしていないか**（v4 は自動伝播しないため未捕捉のまま応答が返らない）
- [ ] `res.json()` / `res.send()` の二重送信（`ERR_HTTP_HEADERS_SENT`）がないか。条件分岐後は `return res...` で早期 return しているか
- [ ] エラー発生時に例外を握りつぶし、正常レスポンス（200）を返していないか

#### 2.1.3 セキュリティ【担当: security-engineer】

- [ ] `helmet` 等でセキュリティレスポンスヘッダを付与しているか。CORS 設定が過度に緩くないか（`origin: "*"` と credentials 併用等）
- [ ] リクエストボディサイズ制限（`express.json({ limit })` 等）があるか（DoS 対策）
- [ ] 入力検証（`express-validator` / `zod` 等）をミドルウェアで行い、Controller に検証済みデータを渡しているか
- [ ] 秘密情報（接続文字列・API キー・JWT シークレット）がハードコードされず、環境変数・設定から注入されているか

#### 2.1.4 パフォーマンス【担当: performance-reviewer】

- [ ] リクエストごとに重いインスタンス（DB 接続・HTTP クライアント）を生成していないか（起動時に一度生成し使い回すべき箇所）
- [ ] ルートハンドラ内での同期 I/O（`fs.readFileSync` / 同期暗号処理等）でイベントループをブロックしていないか

### 2.2 NestJS

#### 2.2.1 モジュール・DI 構造【担当: implementation-engineer】

- [ ] 機能単位でモジュール分割され、巨大な単一 `app.module.ts` にロジックが集約されていないか
- [ ] モジュール間の循環依存に対して `forwardRef` を濫用していないか（多用は設計見直しのサイン）
- [ ] `imports` / `exports` で依存が明示され、プロバイダの公開範囲が適切か
- [ ] ビジネスロジックがコントローラではなくサービス（`@Injectable`）に置かれているか。DI を使わず手動 `new` していないか

#### 2.2.2 検証・パイプライン・例外処理【担当: implementation-engineer / security-engineer】

- [ ] DTO に `class-validator` デコレータが付与され、`ValidationPipe` で検証されているか。**`whitelist: true`（未定義プロパティ除去）/ `forbidNonWhitelisted` が設定され、過剰なプロパティ受け入れ（mass assignment）を防いでいるか**
- [ ] Guard / Interceptor / Pipe / Filter の適用位置（グローバル / コントローラ / ハンドラ）が意図通りか。認証 Guard の適用漏れがないか
- [ ] 例外フィルタ（`@Catch()`）で例外を握りつぶして 200 を返していないか。内部例外の詳細（スタックトレース・SQL 等）をクライアントに露出していないか
- [ ] `@nestjs/config`（`ConfigModule`）でシークレットを一元管理し、コードに直書きしていないか

#### 2.2.3 DI スコープ・パフォーマンス【担当: performance-reviewer】

- [ ] `@Injectable({ scope: Scope.REQUEST })`（REQUEST スコープ）の性能影響を認識しているか（リクエストごとにインスタンスを生成し、依存も伝播して REQUEST 化される）
- [ ] 不要にスコープを狭めていないか（既定のシングルトンで足りる箇所を REQUEST 化していないか）

#### 2.2.4 データアクセス・トランザクション【担当: implementation-engineer】

- [ ] TypeORM / Prisma 連携で、1 トランザクションにまとめるべき複数の書き込みがバラバラに実行されていないか（部分コミットによる不整合）
- [ ] リポジトリ・クエリの N+1 がないか（1 リクエストで N 回のクエリ発行になっていないか。ループ内クエリを避け、まとめ取得・JOIN・eager loading を検討する）

### 2.3 Node.js プロセス運用（Express / NestJS 共通）【担当: implementation-engineer / security-engineer】

- [ ] グレースフルシャットダウン（`SIGTERM` / `SIGINT` で受付停止・処理中リクエスト完了・DB プールクローズ）が実装されているか
- [ ] `unhandledRejection` / `uncaughtException` のハンドラがあり、プロセスの異常状態を検知・ログ・終了できるか
- [ ] ログに機密情報（トークン・パスワード・PII・リクエストボディ全体）を出力していないか

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 秘密情報のハードコード（接続文字列・API キー・JWT シークレット） | Critical | 情報漏洩 |
| 入力検証なしで DB・外部コマンド・クエリへ渡す | Critical〜High | インジェクション |
| ValidationPipe の whitelist 未設定（過剰プロパティ受け入れ） | High | mass assignment |
| async ハンドラの reject 握りつぶし（v4 前提コード） | High | エラー消失・障害の無言化 |
| 例外フィルタ / catch での例外握りつぶし → 200 応答 | High | 障害の無言化 |
| エラーハンドリングミドルウェアの配置順・引数（4 引数）誤り | High | エラーが捕捉されない |
| `res` 二重送信（ERR_HTTP_HEADERS_SENT） | High〜Medium | クラッシュ・応答破損 |
| セキュリティヘッダ（helmet）・ボディサイズ制限の欠如 | Medium〜High | 攻撃面拡大・DoS |
| トランザクション分割による部分コミット | Medium〜High | データ不整合 |
| REQUEST スコープの不用意な多用 | Medium | 性能劣化（負荷時に顕在化） |
| グレースフルシャットダウン・unhandledRejection 未処理 | Medium | 運用時のデータ欠損・異常継続 |
| ミドルウェアの `next()` 呼び忘れ | Medium | リクエストハング |
| ログへの機密情報混入 | Medium〜High | 情報漏洩 |
| モジュール未分割・forwardRef 濫用 | Low〜Medium | 保守性低下 |

### NG / OK 例（Express 4 前提コードの async 握りつぶし）

```js
// NG: v4 前提。async の reject が next(err) に渡らず、応答が返らないまま滞留
app.get("/orders/:id", async (req, res) => {
  const order = await repo.find(req.params.id); // throw すると未捕捉
  res.json(order);
});

// OK(v4): try/catch で明示的に next(err) へ伝播
app.get("/orders/:id", async (req, res, next) => {
  try {
    res.json(await repo.find(req.params.id));
  } catch (err) {
    next(err); // エラーハンドリングミドルウェアへ
  }
});
// OK(v5): Express 5 は Promise reject を自動的に next(err) へ伝播するため try/catch は不要
```

## 4. 関連プロファイル参照

差分に以下が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| 同一リポジトリのフロントエンドが React / Next.js | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| 同一リポジトリのフロントエンドが Vue / Nuxt | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| TypeScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md` |
| JavaScript で実装 | `${CLAUDE_PLUGIN_ROOT}/references/languages/javascript.md` |
