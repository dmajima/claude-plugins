# SQL: MySQL 方言プロファイル

MySQL（および互換の MariaDB）固有の仕様を扱う。方言によらない共通の慣習・安全性・パフォーマンス基本は
[conventions.md](conventions.md)（SQL 共通）に従い、本ファイルは **MySQL 固有の確実な仕様のみ** を記載する。
記載内容は MySQL 公式リファレンスマニュアル（<https://dev.mysql.com/doc/refman/8.0/en/>）に基づく。

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 接続設定 | `mysql://` / 接続文字列に `mysql:` / ドライバ `mysqlclient` `PyMySQL` `mysql2` `MySql.Data` 等 |
| 既定ポート | `3306` |
| コンテナ | `docker-compose.yml` / Dockerfile の `mysql` または `mariadb` イメージ |
| その他 | `my.cnf` / `my.ini`、`AUTO_INCREMENT` や `ENGINE=InnoDB` を含む DDL、バッククォート識別子 |

## 2. 方言仕様

### 2.1 識別子クォート

- 識別子のクォートは **バッククォート** `` `identifier` ``。
  ```sql
  SELECT `order`.`id` FROM `order`;
  ```
- `sql_mode` に `ANSI_QUOTES` が含まれる場合は **ダブルクォート `"..."` も識別子引用符** として扱われる（この場合、文字列リテラルはシングルクォートのみ）。`ANSI_QUOTES` の有無で `"..."` の意味が変わるため、移植性の観点から識別子はバッククォート、文字列はシングルクォートで統一するのが安全。

### 2.2 大文字小文字の扱い

- **テーブル名・データベース名の大文字小文字感度は OS と `lower_case_table_names` システム変数に依存する**。
  - `0`: 大文字小文字を区別（Linux の既定）。ディスク上の格納名どおりに扱われる。
  - `1`: 名前を小文字で格納し、比較時も小文字化（Windows の既定）。区別しない。
  - `2`: 指定どおりに格納するが比較は小文字（macOS の既定）。
- 同一スキーマを異なる OS・設定へ移送すると、大文字混在のテーブル名は「開発機（Windows・非区別）で動くが本番（Linux・区別）で `Table doesn't exist` になる」事故が起きやすい。
- **対策**: テーブル名は **小文字 `snake_case`** で作成し、大文字混在名を避ける（[conventions.md](conventions.md) 2.1 の根拠）。カラム名・カラムのデータは通常この変数の影響を受けない（カラム名は常に非区別、データの区別は列の collation による）。

### 2.3 主要構文

| 用途 | MySQL 構文 |
|------|-----------|
| 連番主キー | `id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY` |
| ページング | `LIMIT <count> OFFSET <offset>`（`LIMIT <offset>, <count>` の順もあるが `LIMIT ... OFFSET ...` が明確） |
| UPSERT | `INSERT ... ON DUPLICATE KEY UPDATE`（下記） |
| ストレージエンジン | `ENGINE=InnoDB`（トランザクション・外部キー・行ロック対応。既定エンジン） |
| 文字集合 | `CHARACTER SET utf8mb4 COLLATE utf8mb4_...`（下記） |

UPSERT の例（一意キー／主キー衝突時に更新）:

```sql
INSERT INTO stock (product_id, qty)
VALUES (10, 5)
ON DUPLICATE KEY UPDATE qty = qty + VALUES(qty);
```

- `VALUES(col)` は挿入しようとした値を参照する古い記法。MySQL 8.0.19 以降は行エイリアス構文（`AS new ... UPDATE qty = qty + new.qty`）が推奨される。プロジェクトの MySQL バージョンに合わせる。

文字集合（重要）:

- **`utf8mb4` を使う**。MySQL の `utf8`（`utf8mb3` のエイリアス）は **1 文字最大 3 バイト** で、絵文字や一部の補助文字（4 バイトの文字）を格納できず、切り詰め・エラーの原因になる。完全な Unicode を扱うには `utf8mb4`（1 文字最大 4 バイト）が必須。
- テーブル・カラム・接続の各レベルで文字集合を `utf8mb4` に揃える。

### 2.4 データ型の注意点

- **`DATETIME` と `TIMESTAMP`**:
  - `DATETIME`: 範囲 `1000-01-01`〜`9999-12-31`。タイムゾーン変換を行わず、格納した値をそのまま返す。
  - `TIMESTAMP`: 範囲 `1970-01-01 UTC`〜`2038-01-19 UTC`（いわゆる 2038 年問題）。UTC で格納され、取得時にセッションのタイムゾーンへ変換される。
  - タイムゾーンをアプリ側で管理するなら `DATETIME`、DB のタイムゾーン変換に載せたい・範囲が 2038 年内なら `TIMESTAMP`、という判断になる。プロジェクトの方針に合わせる。
- **`TINYINT(1)` は BOOLEAN 扱い**。`BOOL` / `BOOLEAN` は `TINYINT(1)` の同義語で、`0` を偽、非 `0` を真として扱う。多くのドライバ・ORM が `TINYINT(1)` を真偽値にマッピングする。
- 金額など誤差が許されない値は `FLOAT`/`DOUBLE` ではなく `DECIMAL(p, s)` を使う。
- `VARCHAR(n)` の `n` は文字数。可変長文字列に用い、固定長が保証される場合のみ `CHAR(n)` を検討する。

## 3. ツールチェーン

| 用途 | コマンド／方法 | 備考 |
|------|--------------|------|
| 実行計画 | `EXPLAIN <statement>` | 見積り実行計画。`EXPLAIN FORMAT=JSON` で詳細 |
| 実実行計画 | `EXPLAIN ANALYZE <statement>` | 実際に実行し、実測の所要時間・行数を出力（**MySQL 8.0.18 以降**） |
| クライアント | `mysql` CLI、MySQL Workbench 等 | |

## 4. イディオム・ベストプラクティス（MySQL 固有）

- InnoDB を使う（既定）。MyISAM はトランザクション・外部キー・行ロック非対応のため新規採用しない。
- 主キーは単調増加する整数（`AUTO_INCREMENT` の `BIGINT`）が InnoDB のクラスタ化インデックスと相性が良い。ランダムな UUID を主キーにするとページ分割・断片化が増えるため、必要な場合は順序性のある UUID（UUIDv7 等）や別列での保持を検討する。
- 多くの DDL（`ALTER TABLE` 等）は **暗黙コミットを伴う**。マイグレーション内で DDL と DML をトランザクションでまとめてロールバックする前提の設計にしない（[conventions.md](conventions.md) 4.1 のトランザクション境界と併せて注意）。
- `WHERE` の索引列に関数を適用しない（`WHERE DATE(created_at) = '2026-01-01'` は索引が効きにくい）。範囲条件に書き換える。

## 5. 典型エラーパターンと対処

| エラー番号 | メッセージ概要 | 原因 | 対処 |
|-----------|--------------|------|------|
| `1062` | Duplicate entry '...' for key '...' | 主キー／一意インデックスの重複挿入 | 事前存在確認、または `INSERT ... ON DUPLICATE KEY UPDATE` |
| `1451` | Cannot delete or update a parent row: a foreign key constraint fails | 子行から参照されている親行を削除／更新した | 先に子行を処理する、または `ON DELETE`/`ON UPDATE` 方針を設計 |
| `1452` | Cannot add or update a child row: a foreign key constraint fails | 親行が存在しないのに子行を挿入／更新した | 親行を先に用意する、外部キー値を見直す |
| `1064` | ... error in your SQL syntax ... | 構文エラー（予約語の未クォート等） | 構文・予約語・方言差を確認 |
| `1146` | Table '...' doesn't exist | テーブル不在（大文字小文字違いを含む） | 2.2 の大文字小文字設定・名前を確認 |

## 6. 関連プロファイル

- 共通の SQL 慣習・安全性・パフォーマンス: [conventions.md](conventions.md)
- ORM 経由で MySQL を扱う場合（Prisma / EF Core / SQLAlchemy / Eloquent）: [orm.md](../../../references/frameworks/orm.md)
- プロジェクト独自規約の優先順位: [`conventions-resolution.md`](../../../references/conventions-resolution.md)
