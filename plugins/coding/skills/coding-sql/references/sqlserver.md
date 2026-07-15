# SQL: SQL Server（T-SQL）方言プロファイル

Microsoft SQL Server の Transact-SQL（T-SQL）固有の仕様を扱う。方言によらない共通の慣習・安全性・パフォーマンス基本は
[conventions.md](conventions.md)（SQL 共通）に従い、本ファイルは **SQL Server 固有の確実な仕様のみ** を記載する。
記載内容は Microsoft Learn の T-SQL 公式ドキュメント（<https://learn.microsoft.com/sql/t-sql/>）に基づく。

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 接続文字列 | `Server=...;Database=...;` に `Trusted_Connection=True` または `Integrated Security=SSPI/true`（Windows 認証）、あるいは `User Id=...;Password=...`（SQL 認証） |
| 既定ポート | `1433` |
| コンテナ | `mcr.microsoft.com/mssql/server`（`mssql`）イメージ |
| その他 | `.sqlproj`（SQL Server Database Project）、ドライバ `Microsoft.Data.SqlClient` / `System.Data.SqlClient` / `pyodbc` + ODBC Driver for SQL Server、角括弧 `[...]` 識別子、`GO` バッチ区切り |

## 2. 方言仕様

### 2.1 識別子クォート

- 識別子のクォートは **角括弧** `[identifier]`。
  ```sql
  SELECT [Order].[Id] FROM [Order];
  ```
- `QUOTED_IDENTIFIER` が `ON`（多くの接続・オブジェクト定義で既定・推奨）の場合は **ダブルクォート `"..."` も識別子引用符** として使える。`OFF` だと `"..."` が文字列扱いになるため挙動が変わる。移植性・一貫性のため、識別子は角括弧、文字列はシングルクォートで統一するのが安全。

### 2.2 大文字小文字の扱い

- **識別子・文字列比較の大文字小文字感度は照合順序（collation）に依存する**。サーバ・データベース・列の各レベルで collation を持つ。
  - collation 名の `CI` = Case-Insensitive（区別しない）、`CS` = Case-Sensitive（区別する）。`AS` = Accent-Sensitive（アクセント区別）。
  - 日本語環境では `Japanese_CI_AS` 等、既定で **CI（非区別）** が用いられることが多い。米国既定は `SQL_Latin1_General_CP1_CI_AS`。
- CI 環境では `WHERE name = 'abc'` が `'ABC'` にもマッチする。区別が必要な比較は明示的に `COLLATE` を付ける（例: `WHERE name COLLATE Japanese_CS_AS = 'abc'`）。
- システムストアドプロシージャ名などは呼び出し時の collation で照合されるため、`sp_help` を `SP_HELP` と書くと CS 環境で解決に失敗しうる。**正確な大文字小文字で記述する**。

### 2.3 主要構文

| 用途 | T-SQL 構文 |
|------|-----------|
| 連番主キー | `Id BIGINT NOT NULL IDENTITY(1,1) PRIMARY KEY`（種 1・増分 1） |
| 件数制限 | `SELECT TOP (n) ...`（`SELECT` では `ORDER BY` と併用する） |
| ページング | `ORDER BY ... OFFSET n ROWS FETCH NEXT m ROWS ONLY`（**`ORDER BY` 必須**） |
| UPSERT | `MERGE`（注意点あり・下記）または `IF EXISTS (...) UPDATE ... ELSE INSERT ...` |
| 一時テーブル | `#temp`（セッションローカル）／ `##temp`（グローバル）／ `@tableVar`（テーブル変数） |
| Unicode 文字列 | `NVARCHAR`／`NCHAR`（下記） |

ページング（Microsoft 公式が `TOP` 代替として案内する方法）:

```sql
SELECT Id, OrderedAt
FROM Orders
ORDER BY OrderedAt DESC
    OFFSET @Skip ROWS
    FETCH NEXT @Take ROWS ONLY;
```

- `OFFSET`/`FETCH` は `ORDER BY` 句の一部であり **`ORDER BY` が必須**。安定したページングには `ORDER BY` に一意性が保証される列（または列の組合せ）を含める。`TOP` と `OFFSET`/`FETCH` は同一クエリスコープで併用できない。

UPSERT:

- `MERGE` は 1 文で INSERT/UPDATE/DELETE を書けるが、**同時実行時の競合・トリガの発火・過去に報告された不具合など運用上の注意点** がある。並行 UPSERT では適切なロック（`HOLDLOCK`／`SERIALIZABLE`）を伴わないと重複挿入や競合が起こりうる。多くの現場では **明示的な `IF EXISTS ... UPDATE ELSE INSERT` をトランザクション内で書く**方が制御しやすい。用途に応じて選ぶ。
  ```sql
  BEGIN TRANSACTION;
  IF EXISTS (SELECT 1 FROM Stock WITH (UPDLOCK, HOLDLOCK) WHERE ProductId = @ProductId)
      UPDATE Stock SET Qty = Qty + @Qty WHERE ProductId = @ProductId;
  ELSE
      INSERT INTO Stock (ProductId, Qty) VALUES (@ProductId, @Qty);
  COMMIT;
  ```

### 2.4 データ型の注意点

- **`NVARCHAR`（Unicode）と `VARCHAR`（非 Unicode）**:
  - `NVARCHAR`/`NCHAR` は Unicode を格納する。日本語などの多言語データは **`NVARCHAR` を使う**のが安全。Unicode リテラルは `N'...'` プレフィクスを付ける（例: `N'日本語'`）。
  - `VARCHAR`/`CHAR` はコードページ（collation）依存の非 Unicode。UTF-8 対応 collation（SQL Server 2019 以降の `_UTF8`）を使う場合を除き、多言語データには使わない。
- 金額は `FLOAT`/`REAL` ではなく `DECIMAL`/`NUMERIC(p, s)` を使う。通貨型 `MONEY` は丸め特性に注意。
- 日時は `DATETIME2`（高精度・広範囲）を推奨。タイムゾーンを保持するなら `DATETIMEOFFSET`。古い `DATETIME` は精度・範囲が限定的。

## 3. ツールチェーン

| 用途 | コマンド／方法 | 備考 |
|------|--------------|------|
| 実行計画 | SSMS の「実行プランの表示（推定／実際）」、`SET SHOWPLAN_ALL ON` | 見積り／実測プラン |
| I/O 統計 | `SET STATISTICS IO ON` | 論理読み取り数などを出力 |
| 時間統計 | `SET STATISTICS TIME ON` | CPU・経過時間を出力 |
| クライアント | SSMS（SQL Server Management Studio）、Azure Data Studio、`sqlcmd` | |

## 4. イディオム・ベストプラクティス（T-SQL 固有）

- **ユーザ定義ストアドプロシージャに `sp_` プレフィクスを使わない**。`sp_` は SQL Server がシステムストアドプロシージャと解釈するため、名前解決規則が変わり（`sp_cache_miss` によるコンパイルロック等の）性能問題や、将来のシステム SP との名前衝突を招く。Microsoft のコード分析ルール **SR0016** でも警告される。`usp_` 等の別プレフィクス、またはプレフィクスなしにする。呼び出し時はスキーマ修飾（`EXEC dbo.MyProc`）する。
- ストアドプロシージャ・バッチの冒頭で **`SET NOCOUNT ON`** を指定し、`N row(s) affected` の余分な結果メッセージを抑止する（ネットワーク往復・一部クライアントの誤動作を減らす）。
- エラー処理は **`TRY...CATCH`** を使い、トランザクションと組み合わせる。予期しないエラーでトランザクションを確実にロールバックするため **`SET XACT_ABORT ON`** を併用するのが定石。
  ```sql
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  BEGIN TRY
      BEGIN TRANSACTION;
      -- 処理
      COMMIT;
  END TRY
  BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK;
      THROW;
  END CATCH;
  ```
- オブジェクト参照はスキーマ修飾する（`dbo.Orders`）。非修飾名は名前解決の余分な探索・キャッシュミスを招く。
- `NOLOCK` ヒント（＝ READ UNCOMMITTED）はダーティリード・重複読み・行欠落のリスクがあるため、安易な性能対策として常用しない。

## 5. 典型エラーパターンと対処

| エラー番号 | メッセージ概要 | 原因 | 対処 |
|-----------|--------------|------|------|
| `2627` | Violation of PRIMARY KEY / UNIQUE constraint | 主キー／一意制約の重複 | 事前存在確認、または UPSERT（2.3） |
| `2601` | Cannot insert duplicate key row in object with unique index | 一意インデックスの重複挿入 | 同上（制約でなく一意インデックス側の違反） |
| `547` | conflicted with the ... constraint | 外部キー／CHECK 制約違反 | 参照先の存在・値の妥当性を確認。削除は子→親順、`ON DELETE` 方針を設計 |
| `208` | Invalid object name '...' | テーブル／ビュー名が無効（スキーマ未修飾・タイポ・collation 差） | スキーマ修飾・名前・存在を確認 |
| `515` | Cannot insert the value NULL into column ... | NOT NULL 列に NULL を挿入 | 値を与える、または列定義／既定値を見直す |
| `8152` / `2628` | String or binary data would be truncated | 列長を超える文字列の挿入 | 列長を拡張、または入力を検証（`2628` は truncation 対象を示す新しめのメッセージ） |

## 6. 関連プロファイル

- 共通の SQL 慣習・安全性・パフォーマンス: [conventions.md](conventions.md)
- ORM 経由で SQL Server を扱う場合（特に EF Core）: [orm.md](../../../references/frameworks/orm.md)
- プロジェクト独自規約の優先順位: [`conventions-resolution.md`](../../../references/conventions-resolution.md)
