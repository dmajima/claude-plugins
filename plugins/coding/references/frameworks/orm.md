# ORM フレームワークプロファイル（Prisma / EF Core / SQLAlchemy / Eloquent）

対象言語プロファイル: [SQL 共通規約](../../skills/coding-sql/references/conventions.md)（SQL 共通の慣習・安全性・パフォーマンス基本はそちらに従う）、および各 ORM のホスト言語プロファイル
（Prisma → [TypeScript 規約](../../skills/coding-typescript/references/conventions.md) / [JavaScript 規約](../../skills/coding-javascript/references/conventions.md)、EF Core → [C# 規約](../../skills/coding-csharp/references/conventions.md)、SQLAlchemy → [Python 規約](../../skills/coding-python/references/conventions.md)、Eloquent → [PHP 規約](../../skills/coding-php/references/conventions.md)）。
本ファイルは **ORM 固有の規約のみ** を扱う。方言固有の DDL・型・エラーは
[MySQL 方言](../../skills/coding-sql/references/mysql.md) / [SQL Server 方言](../../skills/coding-sql/references/sqlserver.md) / [PostgreSQL 方言](../../skills/coding-sql/references/postgresql.md) を参照。

各 ORM のスキーマ定義・命名・マイグレーション・生 SQL の書き方はそれぞれ大きく異なるため、ORM を検出したら
**その ORM の規約を SQL 共通慣習より優先** する（ORM がテーブル名・カラム名を生成・管理するため）。

## 1. 検出

| フレームワーク | ホスト言語 | 検出マーカー |
|--------------|-----------|-------------|
| Prisma | TypeScript / JavaScript | `prisma/schema.prisma`、`package.json` の `prisma`（devDependencies）/ `@prisma/client` |
| Entity Framework Core | C# | `*.csproj` の `Microsoft.EntityFrameworkCore.*` 参照、`DbContext` 派生クラス、`Migrations/` の `*.cs` |
| SQLAlchemy | Python | 依存定義に `SQLAlchemy`、`DeclarativeBase`/`declarative_base()` を用いたモデル、`alembic/` ディレクトリ |
| Eloquent | PHP | `composer.json` の `laravel/framework`、`app/Models/`、`database/migrations/`、`artisan` |

## 2. Prisma

TypeScript/JavaScript 向けの型安全な ORM。スキーマファースト（`schema.prisma` を単一情報源として型付きクライアントを生成）。

### 2.1 プロジェクト構造・配置規則

- スキーマは `prisma/schema.prisma`。`datasource`（接続先・`provider`）、`generator`（クライアント生成）、`model`（テーブル）ブロックで構成。
- `provider` は `postgresql` / `mysql` / `sqlite` / `sqlserver` / `mongodb` 等。接続 URL は環境変数（`env("DATABASE_URL")`）から読む。
- マイグレーションは `prisma/migrations/` に SQL として履歴管理される。
- 生成された Prisma Client（`@prisma/client`）をアプリから import して使う。

### 2.2 FW 固有の命名・実装規約

- **モデル名は PascalCase 単数**（`User`, `OrderItem`）、**フィールド名は camelCase**（`createdAt`）が Prisma の慣習。生成される TypeScript の型・プロパティ名がこれに一致する。
- DB 側の実テーブル名・カラム名が異なる（例: 既存 DB が `snake_case` 複数形）の場合は **`@@map` / `@map`** で対応付ける。Prisma のモデル名は読みやすく保ちつつ、DB 命名に合わせられる。
  ```prisma
  model OrderItem {
    id        Int      @id @default(autoincrement())
    orderId   Int      @map("order_id")
    createdAt DateTime @default(now()) @map("created_at")
    order     Order    @relation(fields: [orderId], references: [id])

    @@map("order_items")
  }
  ```
- 主キーは `@id`。採番は `@default(autoincrement())`（連番）または `@default(uuid())` / `@default(cuid())`。
- リレーションは `@relation(fields: [...], references: [...])` で定義し、両モデルに相互の参照フィールドを置く。
- 一意制約は `@unique` / `@@unique([...])`、インデックスは `@@index([...])`。

### 2.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| マイグレーション作成＋適用（開発） | `prisma migrate dev --name <name>`（マイグレーション生成・適用・クライアント再生成を一括） |
| マイグレーション適用（本番） | `prisma migrate deploy`（未適用のマイグレーションのみ適用。生成はしない） |
| DB リセット（開発のみ） | `prisma migrate reset`（全削除して再適用。データ消失） |
| スキーマを直接反映（試作） | `prisma db push`（マイグレーション履歴を作らずスキーマ状態を反映。プロトタイピング・SQLite 実験向け。本番運用では非推奨） |
| クライアント再生成 | `prisma generate` |
| GUI | `prisma studio` |

- **本番は `migrate deploy`、履歴を残さない `db push` は試作用**。両者を混在させない。

### 2.4 ベストプラクティス・アンチパターン

- **N+1 回避**: 関連を都度ロードせず、`include`（関連を取得）／`select`（取得フィールドを限定）でまとめ取得する。ループ内で個別に `await` してクエリを繰り返さない。
  ```ts
  // OK: 関連をまとめて取得
  const orders = await prisma.order.findMany({
    include: { items: true },
  });
  // NG: ループ内で関連を都度取得（N+1）
  for (const o of orders) {
    o.items = await prisma.orderItem.findMany({ where: { orderId: o.id } });
  }
  ```
- **`select` で必要な列だけ取得** し、過剰なデータ転送を避ける（[SQL 共通規約](../../skills/coding-sql/references/conventions.md) の `SELECT *` 回避と同趣旨）。
- **トランザクション**: 複数操作の原子性は `prisma.$transaction([...])`（配列を順次実行）または対話的トランザクション `prisma.$transaction(async (tx) => { ... })` を使う。
- **生 SQL は必ずパラメータ化**: タグ付きテンプレートの `prisma.$queryRaw`\`...\` は値を自動的にパラメータ化するため安全。文字列を組み立てる `$queryRawUnsafe` はインジェクションの危険があり、外部入力を渡さない。
- スキーマ変更は `schema.prisma` を編集してからマイグレーションを生成する。DB を直接変更してスキーマと乖離させない。

## 3. Entity Framework Core

C#（.NET）向けの ORM。コードファースト（エンティティクラスと `DbContext` からスキーマ・マイグレーションを生成）が主流。

### 3.1 プロジェクト構造・配置規則

- `DbContext` を継承したコンテキストクラスに `DbSet<TEntity>` プロパティを定義し、各エンティティ（POCO クラス）を公開する。
- マッピング設定は `OnModelCreating(ModelBuilder)` に Fluent API で書く。マイグレーションは `Migrations/` に `*.cs` として生成される。
- 接続文字列は `appsettings.json` 等から読み、`DbContextOptions` で `UseSqlServer` / `UseNpgsql` / `UseMySql` 等のプロバイダを指定する。

### 3.2 FW 固有の命名・実装規約

- エンティティ名は PascalCase、`DbSet` プロパティ名が既定のテーブル名になる（複数形にするかはプロジェクトで統一）。
- **設定方法は 2 系統**:
  - **データ注釈（Data Annotations）**: `[Key]` `[Required]` `[MaxLength(n)]` `[Table("...")]` `[Column("...")]` をプロパティ・クラスに付与。簡潔。
  - **Fluent API**: `modelBuilder.Entity<T>()...` で構成。より表現力が高く、複雑な設定（複合キー・リレーション詳細・インデックス）に向く。**両者が競合した場合は Fluent API が優先** される。複雑なマッピングは Fluent API に寄せるのが一般的。
- リレーションはナビゲーションプロパティ（`public Order Order { get; set; }` / `public ICollection<OrderItem> Items { get; set; }`）と外部キープロパティで表現する。

### 3.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| マイグレーション作成 | `dotnet ef migrations add <Name>` |
| マイグレーション適用 | `dotnet ef database update` |
| 直前マイグレーション取り消し（未適用時） | `dotnet ef migrations remove` |
| 特定マイグレーションへロールバック | `dotnet ef database update <PreviousMigrationName>` |

### 3.4 ベストプラクティス・アンチパターン

- **読み取り専用クエリは `AsNoTracking()`** を付け、変更追跡のオーバーヘッドを避ける（性能・メモリ改善）。更新予定のエンティティには付けない。
- **N+1 回避**: 遅延ロード（lazy loading、プロキシ有効時）はループで N+1 を招きやすい。`Include()` / `ThenInclude()` でイーガーロードする。
  ```csharp
  var orders = await db.Orders
      .Include(o => o.Items)
      .AsNoTracking()
      .ToListAsync();
  ```
- **複数 `Include` の直積膨張（cartesian explosion）** には `AsSplitQuery()` を検討する（1 つの巨大 JOIN を複数クエリに分割）。
- `SaveChanges()` / `SaveChangesAsync()` は既定で 1 トランザクションにまとまる。複数の `SaveChanges` をまたいで原子性が必要なら `Database.BeginTransaction()` で明示的に囲む。
- 生 SQL（`FromSqlRaw` / `ExecuteSqlRaw`）は補間ではなくパラメータ（`{0}` プレースホルダや `FromSqlInterpolated` の安全な補間）を使う。

## 4. SQLAlchemy

Python 向けの ORM／SQL ツールキット。ここでは **2.x スタイル**（型注釈ベースの宣言的マッピングと統一クエリ API）を前提とする。

### 4.1 プロジェクト構造・配置規則

- `DeclarativeBase` を継承した `Base` を定義し、各モデルクラスが `__tablename__` とマップドカラムを持つ。
- エンジンは `create_engine(url)`、セッションは `sessionmaker` / `Session`。マイグレーションは **Alembic**（`alembic/versions/` にリビジョンスクリプト）。

### 4.2 FW 固有の命名・実装規約

- 2.x スタイルは **`Mapped[...]` 型注釈＋`mapped_column(...)`** でカラムを定義する。
  ```python
  from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

  class Base(DeclarativeBase):
      pass

  class User(Base):
      __tablename__ = "users"
      id: Mapped[int] = mapped_column(primary_key=True)
      name: Mapped[str] = mapped_column(String(100))
      orders: Mapped[list["Order"]] = relationship(back_populates="user")
  ```
- クエリは 2.0 統一 API の `select()` を使い、`session.execute(select(User).where(...))` または `session.scalars(select(User))` で実行する。レガシーの `session.query(User)` も動くが、新規コードは 2.0 スタイルに統一する。
- テーブル名は `__tablename__` で明示（`snake_case` 複数形が一般的だが統一が重要）。

### 4.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| マイグレーション自動生成 | `alembic revision --autogenerate -m "<msg>"`（メタデータと DB 差分から生成） |
| マイグレーション適用 | `alembic upgrade head` |
| 1 つ戻す | `alembic downgrade -1` |

### 4.4 ベストプラクティス・アンチパターン

- **セッション管理はコンテキストマネージャ** で行い、確実に close／commit／rollback する。
  ```python
  with Session(engine) as session:
      with session.begin():   # ブロック終了時に commit、例外時に rollback
          session.add(obj)
  ```
- **N+1 回避**: リレーションの既定遅延ロードはループで N+1 を招く。**`selectinload()`**（別途 IN クエリ。コレクションの既定候補）や **`joinedload()`**（LEFT JOIN。多対一向き）でイーガーロードする。関係定義側で `lazy="selectin"` を指定する方法もある。
  ```python
  from sqlalchemy.orm import selectinload
  users = session.scalars(
      select(User).options(selectinload(User.orders))
  ).all()
  ```
- **生 SQL は `text()` ＋バインドパラメータ**。f-string で値を埋め込まない。
  ```python
  session.execute(text("SELECT * FROM users WHERE id = :id"), {"id": user_id})
  ```
- Alembic の自動生成は万能ではない（型変更・リネーム等を取りこぼす）。生成されたリビジョンを必ずレビューしてから適用する。

## 5. Eloquent（Laravel）

PHP・Laravel の ActiveRecord 型 ORM。規約による自動マッピングが強い。

### 5.1 プロジェクト構造・配置規則

- モデルは `app/Models/`（`Illuminate\Database\Eloquent\Model` を継承）。マイグレーションは `database/migrations/`。
- スキーマ操作はマイグレーションの `up()` / `down()` 内で Schema ビルダ（`Schema::create('...', function (Blueprint $table) { ... })`）を使う。

### 5.2 FW 固有の命名・実装規約

- **命名規約（自動推論）**: モデル名は **単数 PascalCase**（`Post`）、対応テーブル名は **複数 snake_case**（`posts`）が既定で推論される。主キーは `id`、タイムスタンプ列 `created_at` / `updated_at` は自動管理。
- 規約から外れる場合は明示する:
  - テーブル名: `protected $table = 'my_posts';`
  - 主キー: `protected $primaryKey = 'post_id';`
  - タイムスタンプ自動管理の無効化: `public $timestamps = false;`
- **マスアサインメント対策**: `protected $fillable = [...]`（許可リスト）または `protected $guarded = [...]`（禁止リスト）を必ず設定する。無設定の一括代入は脆弱性になりうる。
- リレーションはメソッドで定義（`hasMany` / `belongsTo` / `belongsToMany` / `hasOne` 等）。

### 5.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| マイグレーション作成 | `php artisan make:migration create_posts_table` |
| マイグレーション適用 | `php artisan migrate` |
| 直近バッチのロールバック | `php artisan migrate:rollback` |
| 全再構築（開発） | `php artisan migrate:fresh`（データ消失） |
| モデル生成 | `php artisan make:model Post -m`（`-m` でマイグレーションも作成） |

### 5.4 ベストプラクティス・アンチパターン

- **N+1 回避**: 関連アクセスの遅延ロードはループで N+1 を招く。**`with()` でイーガーロード** する。
  ```php
  // OK
  $posts = Post::with('comments')->get();
  // NG（各 $post->comments で都度クエリ）
  $posts = Post::all();
  foreach ($posts as $post) { $post->comments; }
  ```
  取得済みモデルには `$post->load('comments')` で後付けイーガーロードもできる。開発環境では `Model::preventLazyLoading()`（`AppServiceProvider::boot` 内、本番以外）で N+1 を検出できる。
- クエリビルダ・Eloquent は内部でパラメータ化される。生 SQL（`DB::select` / `whereRaw`）を書く場合は **バインディングを使う**（`DB::select('... where id = ?', [$id])`）。文字列連結で値を埋め込まない。
- **トランザクション**は `DB::transaction(function () { ... })`（クロージャ内で例外時に自動ロールバック）を使う。

## 6. 共通ベストプラクティス（全 ORM 横断）

- **マイグレーションは後方互換を意識する（expand-contract）**。ORM の自動マイグレーションでも破壊的変更（列削除・リネーム・NOT NULL 化）は 1 ステップで行わず、追加 → 移行 → 削除の段階に分ける。ローリングデプロイ中の新旧アプリ混在に耐える（[SQL 共通規約](../../skills/coding-sql/references/conventions.md) 4.1 参照）。
- **自動生成マイグレーション／生成 SQL は必ずレビューしてから適用する**。ORM は破壊的変更・データ移行・リネームを取りこぼすことがある。本番適用前に生成物（SQL・マイグレーションクラス）を確認する。
- **生 SQL が必要な場面でもパラメータ化を必須とする**。各 ORM の安全な生 SQL 経路（Prisma のタグ付き `$queryRaw`、EF Core の `FromSqlInterpolated`／パラメータ、SQLAlchemy の `text()` ＋バインド、Eloquent のバインディング）を使い、文字列連結で外部入力を埋め込まない（[SQL 共通規約](../../skills/coding-sql/references/conventions.md) 4.1）。
- **トランザクション境界を明示する**。関連する複数の書き込みは 1 トランザクションにまとめ、途中失敗でロールバックする。
- **N+1 を既定で疑う**。一覧取得＋関連アクセスのパターンでは、各 ORM のイーガーロード（`include` / `Include` / `selectinload`・`joinedload` / `with`）を用いる。
- **モデル命名と DB 命名の対応付け** を明示する（Prisma `@@map`、EF Core `[Table]`/Fluent、SQLAlchemy `__tablename__`、Eloquent `$table`）。既存 DB の命名規約（多くは `snake_case`）とホスト言語の命名規約（PascalCase／camelCase）の橋渡しを ORM のマッピング機能に集約する。
- **外部キー列にインデックス** を付ける（多くの ORM／DB で自動付与されるが、確認する）。

## 関連プロファイル

- SQL 共通: [SQL 共通規約](../../skills/coding-sql/references/conventions.md)
- 方言別: [MySQL 方言](../../skills/coding-sql/references/mysql.md) / [SQL Server 方言](../../skills/coding-sql/references/sqlserver.md) / [PostgreSQL 方言](../../skills/coding-sql/references/postgresql.md)
- プロジェクト独自規約の優先順位: [`conventions-resolution.md`](../conventions-resolution.md)
