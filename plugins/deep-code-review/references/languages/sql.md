# SQL レビュー観点プロファイル

SQL コード（DDL / DML / マイグレーション）の変更差分をレビューする際の言語固有観点。SQL には単一のデファクトスタンダード規約が存在しないため、プロジェクト内の既存書式・命名が存在する場合は必ずそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。主担当は【担当: dba】。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.sql` |
| マーカーファイル | `migrations/` ディレクトリ、`db/` / `database/` 配下の SQL、ORM スキーマ（`schema.prisma` / EF Core の `Migrations/*.cs` / Alembic の `alembic/versions/` / Laravel の `database/migrations/`） |
| 方言判定 | 接続設定・ポート・コンテナイメージ・DDL の特徴から判定する（下表） |

| 方言 | 判定マーカー |
|------|-------------|
| MySQL / MariaDB | `mysql://` / ポート `3306` / `mysql`・`mariadb` イメージ / バッククォート `` `id` `` 識別子 / `AUTO_INCREMENT` / `ENGINE=InnoDB` |
| SQL Server（T-SQL） | `Server=...;Database=...` / ポート `1433` / `mcr.microsoft.com/mssql/server` / 角括弧 `[id]` 識別子 / `GO` バッチ区切り / `IDENTITY(1,1)` |
| PostgreSQL | `postgres://` / `postgresql://` / ポート `5432` / `postgres` イメージ / `SERIAL` / `GENERATED ... AS IDENTITY` / `JSONB` / `TIMESTAMPTZ` / `RETURNING` / `ON CONFLICT` |

**方言が判定できない場合は共通規約（本プロファイルのセクション 3.1〜3.6・3.8）のみで評価し、方言固有の指摘（3.7）は「方言確認待ち」と明記する**（誤った方言前提での指摘を避ける）。

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- 各 DBMS 公式リファレンスのコーディング例（MySQL Reference Manual / Microsoft Learn T-SQL / PostgreSQL Documentation）
- SQLFluff 等のスタイルガイド（`.sqlfluff` があればそれを一次情報源とする）
- ORM の命名・DDL 規約（ORM がスキーマを生成する場合は `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` が一次情報源）

## 3. レビュー観点

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`sql-core.md`](sql-core.md) … 3.1 3.4 3.5 3.6 3.7 3.8
> - [`sql-security.md`](sql-security.md) … 3.2 3.3

### 3.1 正確性（NULL 三値論理・JOIN・集計）【担当: dba】

> → 本文は [`sql-core.md`](sql-core.md)（3.1）

### 3.2 安全性（インジェクション・権限）【担当: dba / security-engineer】

> → 本文は [`sql-security.md`](sql-security.md)（3.2）

### 3.3 マイグレーション安全性（後方互換・ロック）【担当: dba / dependency-safety】

> → 本文は [`sql-security.md`](sql-security.md)（3.3）

### 3.4 トランザクション・整合性【担当: dba】

> → 本文は [`sql-core.md`](sql-core.md)（3.4）

### 3.5 命名・スタイル【担当: dba / linter-static-analysis】

> → 本文は [`sql-core.md`](sql-core.md)（3.5）

### 3.6 パフォーマンス（インデックス・実行計画）【担当: dba / performance-reviewer】

> → 本文は [`sql-core.md`](sql-core.md)（3.6）

### 3.7 方言固有観点【担当: dba】

> → 本文は [`sql-core.md`](sql-core.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: dba】

> → 本文は [`sql-core.md`](sql-core.md)（3.8）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 動的 SQL の文字列連結（ユーザ入力含む） | Critical | SQL インジェクション |
| `UPDATE` / `DELETE` の `WHERE` 漏れ | Critical | 全件更新・削除事故 |
| 破壊的マイグレーションを 1 ステップ実施（列削除・リネーム・NOT NULL 化） | High〜Critical | ローリングデプロイ中の新旧混在で停止 |
| 大テーブルの `ALTER` によるロング・ロック | High | 書き込み停止（データ量依存） |
| マイグレーションの冪等性・ロールバック・トランザクション境界の欠如 | High〜Medium | 再実行・途中失敗時のデータ不整合・復旧困難 |
| NULL 三値論理の誤り（`NOT IN` + NULL / `= NULL`） | High | 意図しない空結果・論理誤り |
| インデックス欠落（`WHERE`/`JOIN`/`ORDER BY` 列） | Medium〜High | フルスキャン・性能劣化 |
| 外部キー列のインデックス欠落 | Medium〜High | 多くの DBMS で FK 索引が自動作成されず `JOIN`・親削除のカスケードがフルスキャン化（MySQL/InnoDB は例外） |
| 暗黙型変換による索引不使用 | Medium〜High | 性能劣化（データ量で顕在化） |
| 同一バッチでの列追加→直後参照（SQL Server・`GO` なし） | High | Msg 207 でマイグレーションバッチ全体が失敗 |
| `NOLOCK` 常用（SQL Server） | Medium〜High | ダーティリード・データ不整合 |
| N+1 の温床（ループ内クエリ） | Medium〜High | 往復回数が行数に比例 |
| `SELECT *`（本番コード） | Medium | 列追加破壊・不要 I/O・カバリング阻害 |
| `utf8`（utf8mb3）採用（MySQL） | Medium | 絵文字・補助文字の欠落 |
| 暗黙結合（カンマ結合）・無意味エイリアス | Low〜Medium | 可読性・保守性 |
| 命名規則違反・大文字混在識別子 | Low〜Medium | 方言依存事故・規約整合 |

### NG / OK 例（動的 SQL のインジェクション。T-SQL）

```sql
-- NG: 動的 SQL に値・識別子を直接連結（SQL インジェクション）
DECLARE @sql NVARCHAR(MAX) =
    N'SELECT * FROM ' + @tableName + N' WHERE name = ''' + @name + N'''';
EXEC (@sql);

-- OK: 値は sp_executesql でパラメータ化、識別子は QUOTENAME でエスケープ、列は明示
DECLARE @sql NVARCHAR(MAX) =
    N'SELECT id, name FROM ' + QUOTENAME(@tableName) + N' WHERE name = @name';
EXEC sys.sp_executesql @sql, N'@name NVARCHAR(100)', @name = @name;
```

## 5. フレームワーク観点

差分に以下の ORM が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| Prisma（`schema.prisma` / Prisma Migrate） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |
| EF Core（`Migrations/*.cs` / `DbContext` / `Microsoft.EntityFrameworkCore.*`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |
| SQLAlchemy / Alembic（`alembic/versions/`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |
| Eloquent（Laravel `database/migrations/`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |

ORM がスキーマ・マイグレーション・クエリを生成する場合、命名・DDL・N+1 対策はそちらが一次情報源となる。ORM 経由でも生 SQL（raw query）を書く箇所はパラメータ化を確認する。

## 6. 動的検証コマンド【担当: linter-static-analysis】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| Lint / フォーマット | `sqlfluff lint --dialect <mysql\|tsql\|postgres> <path>`（`.sqlfluff` があれば `--dialect` は不要） | 違反内容に応じて Medium〜Low |
| 自動整形の差分確認 | `sqlfluff fix --diff <path>`（適用はせず差分のみ確認） | 差分あり = Low〜Medium |
| 実行計画（原則手動） | MySQL `EXPLAIN` / SQL Server `SET SHOWPLAN_ALL ON` / PostgreSQL `EXPLAIN (ANALYZE, BUFFERS)` | フルスキャン・想定外の結合検出 = Medium〜High |

- `sqlfluff` は `--dialect` で方言指定が必要。**方言判定不能時は SKIPPED**、または共通ルールのみで実行する。
- 実行計画コマンドは本番 DB 接続を伴うためレビュー時に自動実行しない（手動確認へ誘導）。特に `EXPLAIN ANALYZE`（PostgreSQL）・`EXPLAIN ANALYZE`（MySQL 8.0.18+）は副作用のある文（`INSERT`/`UPDATE`/`DELETE`）で実際に実行される点に注意。
