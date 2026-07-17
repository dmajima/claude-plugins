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

### 3.1 正確性（NULL 三値論理・JOIN・集計）【担当: dba】

- [ ] **NULL 三値論理の誤り**: `= NULL` / `<> NULL`（常に UNKNOWN）を `IS NULL` / `IS NOT NULL` に、`NOT IN (サブクエリ)` は候補に NULL が混入すると全体が空になるため `NOT EXISTS` を検討
- [ ] 集計での NULL 挙動（`COUNT(col)` は NULL を除外、`SUM`/`AVG` も NULL 無視。`COUNT(*)` との差異を意図しているか）
- [ ] **`SELECT *` の使用**（列追加時の予期せぬ挙動・不要な列取得。本番コードでは列を明示。アドホック調査用途は可）
- [ ] JOIN 種別の誤り（`INNER` と `LEFT` の取り違えによる行の欠落・増殖）、結合条件不足による意図しない直積（クロスジョイン）
- [ ] 集計と非集計列の混在で `GROUP BY` に非集計列を漏れなく含めているか（方言により緩いが移植性のため明示）
- [ ] `UNION`（重複排除でソート発生）と `UNION ALL` の使い分けが意図どおりか
- [ ] **`UPDATE` / `DELETE` の `WHERE` 漏れ**（全件更新・削除事故。トランザクション内で `SELECT` により影響範囲を先に確認）

### 3.2 安全性（インジェクション・権限）【担当: dba / security-engineer】

- [ ] **動的 SQL の文字列連結**（ストアドプロシージャ内の `EXEC(@sql)` 等でユーザ入力を連結 → SQL インジェクション。パラメータ化＝`sp_executesql` / プレースホルダ、識別子は `QUOTENAME` 等でエスケープ）
- [ ] 生 SQL（ORM の raw query 含む）でプレースホルダ（`?` / `$1` / `:name` / `@name`）とバインド値を使わず値を埋め込んでいないか
- [ ] 過剰な権限付与（`GRANT ALL` / アプリユーザへの `DROP`・`ALTER` 権限。最小権限の原則）
- [ ] 機密情報（接続文字列・パスワード・API キー）を SQL・マイグレーション・シードにハードコードしていないか
- [ ] `GRANT` / `REVOKE` / ロール変更が意図した対象・範囲か（`PUBLIC` への広範な付与に注意）

### 3.3 マイグレーション安全性（後方互換・ロック）【担当: dba / dependency-safety】

- [ ] **破壊的変更を 1 ステップで実施していないか**（列削除・リネーム・型変更・NOT NULL 化）。expand-contract の 3 段階（expand: 追加 → migrate: 移行 → contract: 削除）でローリングデプロイ中の新旧アプリ混在に耐えるか
- [ ] 大テーブルへの `ALTER`（列追加・インデックス作成）のロック時間・実行時間を見積もっているか（書き込み停止のリスク）
- [ ] **既定値付き NOT NULL 列の追加**が、対象方言・バージョンでメタデータのみの操作になるか（既定値なしで NOT NULL を追加し既存行違反にならないか。大テーブルでの全行書き換えを避ける）
- [ ] ロールバック手順（down マイグレーション）が定義され、かつ安全か（データ損失を伴う down になっていないか）
- [ ] インデックス作成でオンライン方式を使えるか（PostgreSQL `CREATE INDEX CONCURRENTLY` / MySQL の `ALGORITHM=INPLACE`）
- [ ] マイグレーションの冪等性・再実行安全性（`IF NOT EXISTS` 等）

### 3.4 トランザクション・整合性【担当: dba】

- [ ] 関連する複数の変更が 1 トランザクションにまとまり、途中失敗時にロールバックされるか
- [ ] 分離レベルの妥当性（ダーティリード・ノンリピータブルリード・ファントムの許容可否）
- [ ] **デッドロックリスク**（複数トランザクションでのロック取得順序を統一しているか。更新順序の不一致がデッドロックを招く）
- [ ] 大量更新・削除のバッチ分割（1 回の巨大 `UPDATE`/`DELETE` はロック保持・ログ肥大・レプリケーション遅延を招く。主キー範囲や `LIMIT`/`TOP` で分割し各バッチをコミット）
- [ ] DDL のトランザクション挙動が方言前提と合っているか（PostgreSQL は多くの DDL がロールバック可能、MySQL は多くの DDL が暗黙コミット。3.7 参照）

### 3.5 命名・スタイル【担当: dba / linter-static-analysis】

- [ ] 命名規則: テーブル・カラムは小文字 `snake_case`、主キー `id` / `<table>_id`、外部キー `<参照テーブル単数>_id`、制約は種別接頭辞（`pk_`/`fk_`/`uq_`/`ck_`）— プロジェクト内で統一されているか
- [ ] **大文字混在の識別子**（`OrderItems` 等）を避けているか（方言によりクォート必須化・環境間移送事故の温床。3.7 参照）
- [ ] 予約語（`order` / `user` / `group` 等）を識別子に使っていないか
- [ ] 明示的 JOIN 構文（カンマ結合 `FROM a, b WHERE ...` を避ける）、意味のあるエイリアス（`a`/`b` でなく `orders AS o`）
- [ ] 列を明示した `INSERT`（`INSERT INTO t (col1, col2) VALUES ...`）、文字列リテラルはシングルクォート
- [ ] キーワード大文字・主要句の改行・インデントがプロジェクト書式と整合しているか

### 3.6 パフォーマンス（インデックス・実行計画）【担当: dba / performance-reviewer】

- [ ] **インデックス欠落**: `WHERE` の絞り込み列・`JOIN` の結合列・`ORDER BY` のソート列にインデックスがあるか
- [ ] **外部キー列のインデックス欠落**: `FOREIGN KEY` 制約を張った参照元列にインデックスがあるか。多くの DBMS（SQL Server / PostgreSQL / Oracle 等）は **FK 制約で参照元列の索引を自動作成しない**ため、`JOIN`・親テーブルの `DELETE`/`UPDATE` 時のカスケード/整合性チェックがフルスキャン化しやすい（MySQL/InnoDB は自動作成するため方言に注意）
- [ ] 複合インデックスの列順（等値比較・選択性の高い列を先頭に。左端プレフィクスの原則）、および過剰インデックス（書き込みコスト・容量とのトレードオフ）
- [ ] **暗黙型変換による索引不使用**（文字列列に数値を比較する等の型不一致 → non-sargable でフルスキャン）
- [ ] **索引列への関数適用**（`WHERE DATE(created_at) = ...` は索引が効かない。範囲条件 `>= ... AND < ...`・式インデックス・生成列を検討）
- [ ] 前方一致でない `LIKE '%foo%'` の多用（通常インデックス不使用。全文検索・専用索引を検討）
- [ ] **N+1 の温床**（一覧取得後に各行の関連を都度取得する SQL パターン。`JOIN`/`IN` のまとめ取得、ORM のイーガーロードへ誘導。アプリ側観点は `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md`）
- [ ] `SELECT *` によるカバリングインデックス阻害・不要 I/O（3.1 とも関連）
- [ ] 遅いクエリは実行計画（`EXPLAIN` 系）でフルスキャン・不要ソート・想定外の結合順序を確認したか

### 3.7 方言固有観点【担当: dba】

**方言判定不能時は本節をスキップし「方言確認待ち」と記録する。**

#### MySQL / MariaDB

- [ ] 文字集合が `utf8mb4` か（`utf8`＝`utf8mb3` は 1 文字最大 3 バイトで絵文字・補助文字が壊れる。テーブル・カラム・接続で統一）
- [ ] ストレージエンジンが `InnoDB` か（`MyISAM` はトランザクション・外部キー・行ロック非対応。新規採用しない）
- [ ] `lower_case_table_names` 依存の大文字混在テーブル名（Windows で動くが Linux 本番で `Table doesn't exist` になる移送事故）
- [ ] `ONLY_FULL_GROUP_BY`（`sql_mode`）を前提に、GROUP BY に非集計列を含めているか
- [ ] DDL の暗黙コミットを前提に、マイグレーションで DDL と DML をトランザクションでまとめてロールバックする設計にしていないか
- [ ] 主キーは単調増加整数（`BIGINT AUTO_INCREMENT`）か（ランダム UUID 主キーは InnoDB クラスタ化索引でページ分割・断片化）

#### SQL Server（T-SQL）

- [ ] **同一バッチ内での「列追加 → 直後参照」**（`ALTER TABLE ... ADD <col>` の後、`GO` を挟まず同一バッチで新列を `UPDATE` / `SELECT` 参照すると、T-SQL はバッチ単位でコンパイルするため Msg 207「Invalid column name」でバッチ全体が失敗する。マイグレーションでは列追加後に `GO`（バッチ区切り）を挿入して参照を別バッチに分離する）
- [ ] **`NOLOCK` ヒント（＝ READ UNCOMMITTED）の常用**（ダーティリード・重複読み・行欠落。安易な性能対策として使わない）
- [ ] **`MERGE` の罠**（並行 UPSERT でロックなしだと重複挿入・競合。`IF EXISTS ... UPDATE ELSE INSERT` を `UPDLOCK, HOLDLOCK` 付きトランザクションで書く方が制御しやすい）
- [ ] 多言語データに `NVARCHAR`（Unicode リテラルは `N'...'`）を使っているか（`VARCHAR` は collation 依存）
- [ ] collation（大文字小文字感度 `CI`/`CS`）を前提とした比較になっているか。区別が必要なら明示的に `COLLATE`
- [ ] ユーザ定義ストアドプロシージャに `sp_` プレフィクスを使っていないか（システム SP と誤解釈・SR0016 警告。`usp_` 等へ）
- [ ] バッチ・SP 冒頭の `SET NOCOUNT ON` / `SET XACT_ABORT ON` + `TRY...CATCH`、オブジェクトのスキーマ修飾（`dbo.Orders`）
- [ ] `OFFSET ... FETCH` ページングに安定した `ORDER BY`（一意列）が付いているか

#### PostgreSQL

- [ ] 新規の連番主キーに `SERIAL` でなく `GENERATED ALWAYS AS IDENTITY` を使っているか（`SERIAL` は所有権・権限・ダンプ挙動で扱いにくい）
- [ ] **大文字混在識別子の畳み込み**（引用符なし識別子は小文字化。大文字混在で作ると以後すべてダブルクォート必須の事故）
- [ ] 時刻列に `TIMESTAMPTZ`（`TIMESTAMP without time zone` は地域をまたぐと解釈が曖昧）
- [ ] **VACUUM の影響**（MVCC の dead tuple 肥大・統計陳腐化。大量更新テーブルは autovacuum 設定・手動 `VACUUM (ANALYZE)`。`VACUUM FULL` は排他ロック）
- [ ] トランザクショナル DDL を前提にしつつ、`CREATE INDEX CONCURRENTLY` 等トランザクション内で使えない文を混在させていないか
- [ ] 上限が明確な場合のみ `VARCHAR(n)`、それ以外は `TEXT`（両者に性能差はない）

### 3.8 コメント・ドキュメント整合【担当: dba】

- [ ] コメントの記述と SQL の実挙動の乖離（変更差分で SQL だけ変わりコメントが古いまま）
- [ ] マイグレーションの説明・チケット参照と実際の DDL/DML の不一致
- [ ] コメントアウトされた SQL の残留

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
