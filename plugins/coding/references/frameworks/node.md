# Node.js サーバーフレームワークプロファイル

対象言語プロファイル: [JavaScript 規約](../../skills/coding-javascript/references/conventions.md) / [TypeScript 規約](../../skills/coding-typescript/references/conventions.md)（言語規約はそちらに従う。本ファイルは FW 固有規約のみ）

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Express 5 | `package.json` の dependencies に `express`（`"express": "^5..."`）。バージョン指定で 4 系と 5 系を判別する |
| NestJS | `package.json` の dependencies に `@nestjs/core` / `@nestjs/common`、プロジェクトルートに `nest-cli.json` |

## 2. Express 5

Express は最小構成のルーティング・ミドルウェアフレームワーク。5.x が現行の `latest`（npm）である。
出典: 公式サイト https://expressjs.com/ / 移行ガイド https://expressjs.com/en/guide/migrating-5.html

### 2.1 プロジェクト構造・配置規則

Express 自体はディレクトリ構造を強制しない。広く採用される層分離は以下。

```
src/
├── app.ts            # express() インスタンス生成・ミドルウェア・ルーター登録（起動はしない）
├── server.ts         # app.listen()（起動責務を分離）
├── routes/           # ルーター定義（express.Router()）
├── controllers/      # リクエスト/レスポンス処理（HTTP 層）
├── services/         # ビジネスロジック（HTTP 非依存）
├── middlewares/      # 認証・バリデーション・エラーハンドラ
└── models/           # データアクセス（Prisma 等）
```

- **Router / Controller / Service を分離** する。Controller は `req` / `res` を扱い、Service は HTTP に依存しない純粋なロジックを持つ（テスト容易性のため）
- `app`（アプリ定義）と `server`（`listen` 起動）を分けると、テスト時に `listen` せず `app` を supertest 等へ直接渡せる

### 2.2 FW 固有の命名・実装規約

- **ルーター分割**: 機能単位で `express.Router()` を作り、`app.use("/users", usersRouter)` でマウントする
- **ミドルウェアチェーン**: `(req, res, next)` シグネチャ。処理を次へ渡すには `next()` を呼ぶ
- **エラーハンドリングミドルウェア**: 引数 4 つ `(err, req, res, next)` で定義し、**すべてのルーター登録の後（最後）** に `app.use()` する
- **Express 5 の async エラー自動伝播**: ルートハンドラ・ミドルウェアが返した Promise が reject した場合（`async` 関数が throw した場合を含む）、Express 5 は自動的に `next(err)` を呼びエラーハンドラへ伝播する。Express 4 で必要だった各ハンドラの `try/catch` + `next(err)` 定型や `express-async-handler` 等のラッパーは Express 5 では不要になった（同期的に throw されるエラーは 4 系同様に捕捉される）
- レスポンスは `res.json()` / `res.status(code).json()` を使う

Express 4 → 5 の主な差分（移行・生成時の注意）:

| 4 系 | 5 系 |
|------|------|
| `app.del(...)` | `app.delete(...)`（`app.del` は廃止） |
| `req.param(name)` | `req.params` / `req.query` / `req.body` を直接参照（`req.param` は廃止） |
| `app.get("/*", ...)`（無名ワイルドカード） | `app.get("/*splat", ...)`（ワイルドカードに名前が必須、`path-to-regexp` 更新による） |

### 2.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| 導入 | `npm install express@5`（TS: 併せて `npm install -D @types/express`） |
| dev（ウォッチ実行） | `node --watch src/server.js` / `nodemon` / TS は `tsx watch src/server.ts` |
| build（TS の場合） | `tsc`、またはバンドラ（`tsup` 等） |
| test | `vitest` / `jest` + `supertest`（HTTP 層の結合テスト） |

補足: scaffold ツール `express-generator` は存在するが、生成される雛形は簡素なため、実プロジェクトでは 2.1 の構成を手動で組むことが多い。

### 2.4 ベストプラクティス・アンチパターン

- Service 層を HTTP 非依存に保ち、`req` / `res` を Service に渡さない
- エラーハンドリングミドルウェアを 1 箇所に集約し、各ハンドラの個別 `try/catch` を減らす（Express 5 の自動伝播を活用）
- 入力検証をミドルウェア（`zod` 等）で行い、Controller には検証済みデータを渡す
- 環境変数・秘匿情報はコードに直書きせず設定から注入する
- セキュリティミドルウェア（`helmet` 等）と CORS 設定を明示する
- アンチパターン: 巨大な単一 `app.js` にルート・ロジックを集約、`async` ハンドラのエラー未処理（特に Express 4 系）、Service 層への `res` オブジェクト漏れ

## 3. NestJS

NestJS は TypeScript ファーストの構造化サーバーフレームワーク。Angular に着想を得た DI・デコレータ・モジュール構造を持つ。
出典: 公式ドキュメント https://docs.nestjs.com/

### 3.1 プロジェクト構造・配置規則

機能ごとに **モジュール** で分割する。1 機能 = 1 ディレクトリが基本。

```
src/
├── main.ts                    # NestFactory によるブートストラップ
├── app.module.ts              # ルートモジュール
└── users/
    ├── users.module.ts        # @Module（controllers / providers を束ねる）
    ├── users.controller.ts    # @Controller（ルーティング・HTTP 層）
    ├── users.service.ts       # @Injectable（ビジネスロジック・プロバイダ）
    ├── dto/                   # DTO（リクエスト/レスポンスの型 + バリデーション）
    └── entities/              # エンティティ（ORM モデル）
```

### 3.2 FW 固有の命名・実装規約

- **ファイル名は `<name>.<役割>.ts` 形式**（`users.controller.ts` / `users.service.ts` / `users.module.ts`）。Nest CLI が生成する標準命名
- **モジュール**: `@Module({ controllers, providers, imports, exports })` で機能単位を構成する
- **コントローラ**: `@Controller("users")` + `@Get()` / `@Post()` 等のルートデコレータ
- **プロバイダ（サービス）**: `@Injectable()` を付与し、DI で注入する
- **DI**: `constructor(private readonly usersService: UsersService) {}` の形でコンストラクタ経由で依存を注入する
- **DTO + バリデーション**: `class-validator` / `class-transformer` を DTO クラスに付与し、`ValidationPipe` で検証する
- クラス名は PascalCase（`UsersController` / `UsersService` / `UsersModule`）

### 3.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| CLI 導入 | `npm i -g @nestjs/cli` |
| プロジェクト生成 | `nest new <project>` |
| scaffold（リソース一式） | `nest g resource users`（module + controller + service + DTO + テストを生成） |
| scaffold（個別） | `nest g module users` / `nest g controller users` / `nest g service users` |
| dev | `nest start --watch`（または `npm run start:dev`） |
| build | `nest build` |
| test | `jest`（`npm run test`）、E2E は `npm run test:e2e` |

### 3.4 ベストプラクティス・アンチパターン

- 1 機能 1 モジュールで凝集度を高め、`imports` / `exports` で依存を明示する
- ビジネスロジックはコントローラではなくサービス（プロバイダ）に置く
- グローバルな例外フィルタ（`@Catch()` / `ExceptionFilter`）とバリデーションパイプでエラー・入力検証を横断的に扱う
- 設定は `@nestjs/config`（`ConfigModule`）で一元管理する
- CLI（`nest g`）で雛形を生成し、命名・構造の一貫性を保つ
- アンチパターン: コントローラへのビジネスロジック混入、DI を使わない手動 `new`、モジュール分割を行わない巨大な `app.module.ts`
