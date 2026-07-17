# ORM レビュー観点プロファイル（Prisma / EF Core / SQLAlchemy / Eloquent）

ORM が関与する変更差分をレビューする際の FW 固有観点。各 ORM のホスト言語プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md` 等）と SQL 共通観点を先に適用し、本ファイルはそれに上乗せする。ORM はテーブル名・カラム名を生成・管理するため、ORM を検出したら **その ORM の規約を SQL 共通慣習より優先** する。プロジェクト独自規約が存在する場合はそちらを優先する。

## 1. 対象と検出条件

| ORM | ホスト言語 | 検出マーカー |
|-----|-----------|-------------|
| Prisma | TypeScript / JavaScript | `prisma/schema.prisma`、`package.json` の `prisma`（devDependencies）/ `@prisma/client` |
| Entity Framework Core | C# | `*.csproj` の `Microsoft.EntityFrameworkCore.*` 参照、`DbContext` 派生クラス、`Migrations/` の `*.cs` |
| SQLAlchemy | Python | 依存定義の `SQLAlchemy`、`DeclarativeBase` / `declarative_base()` を用いたモデル、`alembic/` ディレクトリ |
| Eloquent | PHP | `composer.json` の `laravel/framework`、`app/Models/`、`database/migrations/`、`artisan` |

EF Core は本ファイル（ORM 横断）と `${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md`（.NET 統合面）の両方に観点がある。両者を併読する。

## 2. FW ごとのレビュー観点

### 2.1 全 ORM 横断（4 ORM 共通）

- [ ] **N+1 クエリ**: 一覧取得後にループ内で関連へアクセスし、遅延読み込みでクエリが件数分発行されていないか【担当: performance-reviewer / dba】
- [ ] **eager loading の適切な指定**: 関連取得を一括化しているか（Prisma `include` / EF Core `Include` / SQLAlchemy `selectinload`・`joinedload` / Eloquent `with`）【担当: performance-reviewer】
- [ ] **必要列のみの射影**: 全列取得（`SELECT *` 相当）を避け、使う列だけ取得しているか（Prisma `select` / EF Core `Select` / SQLAlchemy カラム指定 / Eloquent `select`）【担当: performance-reviewer / dba】
- [ ] **トランザクション境界**: 関連する複数書き込みを 1 トランザクションにまとめ、途中失敗でロールバックしているか【担当: implementation-engineer / dba】
- [ ] **生 SQL 逃げ道のパラメタライズ**: 各 ORM の安全な生 SQL 経路を使い、文字列連結で外部入力を埋め込んでいないか【担当: security-engineer】
- [ ] **バルク操作**: ループ内 1 件ずつの INSERT / UPDATE になっていないか（バルク API・一括挿入の検討）【担当: performance-reviewer / dba】
- [ ] **大量結果のページネーション**: 全件取得を前提にしていないか。ページング（offset / keyset）や上限を設けているか【担当: performance-reviewer / dba】
- [ ] **外部キー列のインデックス**: JOIN / 絞り込みに使う外部キー列にインデックスがあるか（多くの ORM で自動付与されるが、複合キー・追加インデックスは要確認）【担当: dba】
- [ ] **楽観的並行性制御**: 競合しうる更新にバージョン列（EF Core `RowVersion` / Prisma `@updatedAt` + 条件更新 / SQLAlchemy `version_id_col` / Eloquent の条件付き更新）を用意し、ロストアップデートを防いでいるか【担当: implementation-engineer / dba】
- [ ] **マイグレーションとモデルの整合**: 自動生成マイグレーション / 生成 SQL をレビュー済みか。破壊的変更（列削除・リネーム・NOT NULL 化）を expand-contract で段階化しているか【担当: dba / dependency-safety】
- [ ] **モデル命名と DB 命名の対応付け**: 明示されているか（Prisma `@@map` / EF Core `[Table]`・Fluent / SQLAlchemy `__tablename__` / Eloquent `$table`）【担当: dba】

```
// N+1 の共通パターン: 一覧を引いた後、ループ内で関連を都度取得している箇所を疑う。
// 修正は各 ORM の eager loading（include / Include / selectinload / with）に置き換える。
```

### 2.2 Prisma（TypeScript / JavaScript）

- [ ] **`select` / `include` の過剰取得**: 使わない関連・列まで取得していないか。ネストした `include` が意図せず巨大なオブジェクトグラフを引いていないか【担当: performance-reviewer】
- [ ] **生 SQL のパラメタライズ**: タグ付きテンプレート ``$queryRaw`...` `` を使い、`$queryRawUnsafe`（文字列組み立て）に外部入力を渡していないか【担当: security-engineer】
- [ ] **interactive transactions**: 複数操作の原子性に `$transaction([...])` / `$transaction(async (tx) => {...})` を使っているか。トランザクション内の長時間処理でタイムアウトしないか【担当: implementation-engineer / dba】
- [ ] **connection pool**: サーバーレス / 多重起動環境で `PrismaClient` を都度 new し接続を枯渇させていないか（シングルトン共有）。プール上限（`connection_limit`）の設定が妥当か【担当: performance-reviewer / dba】
- [ ] **ネスト write / upsert の範囲**: `create` / `update` のネスト書き込み・`upsert` が意図した関連だけを操作しているか（過剰な `connect` / `create`）【担当: implementation-engineer】

```ts
// NG: 文字列組み立てを $queryRawUnsafe に渡す（SQL インジェクション）
await prisma.$queryRawUnsafe(`SELECT * FROM users WHERE email = '${email}'`);
// OK: タグ付きテンプレートで自動パラメータ化
await prisma.$queryRaw`SELECT * FROM users WHERE email = ${email}`;
```

### 2.3 Entity Framework Core（C#）

EF Core の N+1・`AsNoTracking`・生 SQL・トランザクション・マイグレーション観点は `${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` 節 2.2 が正典。本節では ORM 横断観点への追加分のみを扱う。

- [ ] **ChangeTracker 肥大化**: 大量エンティティを追跡状態でロードし、変更追跡がメモリと `SaveChanges` を圧迫していないか。読み取り専用は `AsNoTracking()`【担当: performance-reviewer】
- [ ] **複数 `Include` の直積膨張（cartesian explosion）**: 巨大 JOIN の重複行が発生していないか → `AsSplitQuery()` の検討【担当: performance-reviewer / dba】

### 2.4 SQLAlchemy（Python）

- [ ] **session スコープ管理**: セッションをコンテキストマネージャ（`with Session(engine) as session:` / `session.begin()`）で確実に commit / rollback / close しているか。リクエストを跨いだ使い回し・close 漏れがないか【担当: implementation-engineer / dba】
- [ ] **`selectinload` / `joinedload` の選択**: コレクションは `selectinload`（別 IN クエリ）、多対一は `joinedload`（LEFT JOIN）が既定候補。誤った選択で直積膨張・過剰クエリになっていないか【担当: performance-reviewer】
- [ ] **2.0 スタイルと 1.x スタイルの混在**: 新規コードが `select()` 統一 API か、レガシー `session.query()` と混在していないか（挙動差・保守性）【担当: implementation-engineer】
- [ ] **`text()` のバインドパラメータ**: 生 SQL は `text("... :id")` + バインド辞書を使い、f-string で値を埋め込んでいないか【担当: security-engineer】
- [ ] **commit 後のデタッチアクセス**: `expire_on_commit`（既定 True）により commit 後の属性アクセスが再クエリを発生・`DetachedInstanceError` を招いていないか【担当: implementation-engineer / performance-reviewer】

```python
# NG: f-string で値を埋め込む（SQL インジェクション）
session.execute(text(f"SELECT * FROM users WHERE id = {user_id}"))
# OK: バインドパラメータ
session.execute(text("SELECT * FROM users WHERE id = :id"), {"id": user_id})
```

### 2.5 Eloquent（PHP / Laravel）

- [ ] **N+1（`with()` eager loading / `lazy()`）**: 一覧 + 関連アクセスで `with()` を使っているか。開発環境で `Model::preventLazyLoading()` により検出しているか【担当: performance-reviewer】
- [ ] **mass assignment（`$fillable` / `$guarded`）**: モデルに許可リスト / 禁止リストが設定されているか。無設定の一括代入（`Model::create($request->all())` 等）で意図しない列を書き換えられないか【担当: security-engineer】
- [ ] **チャンク処理（`chunk` / `cursor`）**: 大量レコードを `all()` / `get()` で一括ロードしメモリを圧迫していないか → `chunk()` / `cursor()` でストリーミング【担当: performance-reviewer】
- [ ] **クエリスコープの活用**: 繰り返す絞り込み条件をローカル / グローバルスコープに集約し、条件漏れ（論理削除の `withTrashed` 等）を防いでいるか【担当: implementation-engineer】
- [ ] **`whereHas` / `withCount` の多用**: 相関サブクエリの多用で重いクエリになっていないか（必要に応じて JOIN・集計の見直し）【担当: performance-reviewer】
- [ ] **`DB::raw` / `whereRaw` のパラメタライズ**: バインディング（`DB::select('... = ?', [$id])`）を使い、文字列連結で値を埋め込んでいないか【担当: security-engineer】

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 生 SQL（`$queryRawUnsafe` / `whereRaw` / `text()` f-string 等）への外部入力連結 | Critical | SQL インジェクション |
| Eloquent mass assignment（`$fillable`/`$guarded` 無設定 + `all()` 代入） | Critical〜High | 権限昇格・意図しない列改ざん |
| マイグレーションの破壊的変更（1 ステップ列削除・NOT NULL 化） | High | ローリングデプロイ中の障害・データ損失 |
| N+1（ループ内遅延読み込み） | High〜Medium | 性能崩壊（データ量依存） |
| トランザクション境界の欠落（複数書き込みが非原子的） | High | 部分適用によるデータ不整合 |
| 楽観的並行性トークン欠落（競合更新） | High〜Medium | ロストアップデート（データ上書き） |
| 大量結果の全件取得（ページネーション欠落） | High〜Medium | メモリ枯渇・レイテンシ悪化（件数依存） |
| 外部キー列のインデックス欠落 | Medium | JOIN / 絞り込みの性能劣化 |
| Prisma connection pool 枯渇（サーバーレスで都度 new） | High〜Medium | 接続枯渇による停止（負荷時に顕在化） |
| SQLAlchemy session の close / rollback 漏れ | High〜Medium | 接続リーク・トランザクション滞留 |
| EF Core ChangeTracker 肥大化・直積膨張 | Medium〜High | メモリ・性能劣化（大量データ） |
| eager loading 未指定 / 過剰取得（`select`/`include` 過多） | Medium | 転送量増・レイテンシ悪化 |
| バルク操作の 1 件ずつ INSERT | Medium | ラウンドトリップ増（件数依存） |
| モデル命名と DB 命名の対応付け欠落 | Low〜Medium | 保守性・可読性 |

## 4. 動的検証【担当: dba / dependency-safety】

生成マイグレーション・生成 SQL は適用前に必ずレビューする（ORM は破壊的変更・リネームを取りこぼす）。対応する Bash 権限がある場合のみ ORM のマイグレーションコマンドで差分を確認（なければ SKIPPED）:

| ORM | マイグレーション差分確認 |
|-----|----------------------|
| Prisma | `prisma migrate diff` / 生成された `prisma/migrations/**/migration.sql` の目視 |
| EF Core | `dotnet ef migrations script`（`${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` 節 4 と共通） |
| SQLAlchemy | `alembic upgrade --sql`（オフライン SQL 生成）で `alembic/versions/*.py` を検証 |
| Eloquent | `php artisan migrate --pretend`（実行 SQL のドライラン表示） |

## 5. 関連プロファイル参照

| 参照先 | 用途 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/frameworks/dotnet.md` | EF Core の .NET 統合面・詳細観点（`DbContext` ライフタイム・トランザクション・N+1） |
| `${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md` | EF Core のホスト言語（C#）共通観点 |
