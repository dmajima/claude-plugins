# Case 01: 方言判定可能・単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この集計クエリを書いて」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `prisma/schema.prisma` に `provider = "postgresql"` があるリポジトリ。対象は集計クエリ 1 ファイル。変更見込み 1 ファイル |

## 期待動作

単独実行モードの実行フロー 6 段を実施する（先頭に方言判定）。

### ステップ1: 方言判定
- SSOT `../../../references/skill-index.md`（および `../../../references/language-detection.md` Step 3）に従い、判定材料（ORM 設定の provider・接続設定／ポート／コンテナイメージ・既存 `.sql` の方言固有構文）を走査
- `prisma/schema.prisma` の `provider = "postgresql"` を検出し、方言を PostgreSQL に確定
- [references/postgresql.md](../references/postgresql.md) を適用対象に追加

### ステップ2: 規約解決
- SSOT `../../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`.sqlfluff` / `.editorconfig`・ORM スキーマの命名／DDL 規約・`CLAUDE.md`・既存 `.sql` の書式／命名慣習）を走査
- 独自規約がない項目は [references/conventions.md](../references/conventions.md) の慣習（キーワード大文字・snake_case・明示的 JOIN・`SELECT *` 回避）を適用

### ステップ3: ORM 確認
- `prisma/schema.prisma` が命名・DDL の一次情報源となる場合は SSOT `../../../references/frameworks/orm.md` を併用（本ケースは生 SQL の集計クエリのため、テーブル／カラム命名整合の参照が主）

### ステップ4: 実装
- PostgreSQL プロファイル（`date_trunc` 等の方言固有関数）と解決規約に従い集計クエリを実装
- ユーザ入力を含むクエリは必ずパラメータ化（文字列連結禁止）

### ステップ5: 検証
- `.sqlfluff` があれば `sqlfluff lint` / `sqlfluff fix`、実行計画は方言別コマンド（`EXPLAIN`）で確認
- DB 接続やツールが無く実行できない検証は SKIPPED として報告

### ステップ6: 報告
- 変更ファイル・適用した方言（PostgreSQL）と規約の根拠（独自規約 or 慣習）・検証結果を報告
- コミット・push・マイグレーション実行はユーザの明示指示があるまで行わない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 適用方言 | PostgreSQL（`provider = "postgresql"` から確定） |
| ユーザへの確認 | 方言確定済みのため方言に関する AskUserQuestion 不発火 |
| 生成ファイル | リポジトリへのコード変更（集計クエリ 1 ファイル）。セッション成果物 6 種は生成しない |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは SQL 方言の判定可否 = 可能（`provider = "postgresql"`）かつ タスク規模 = 小 である。
方言が判定でき、かつタスク規模が小さいため、`orchestrator-coding` ではなく言語スキル単独で処理する。
境界: フェーズ統括・複数言語・スキーマ全体設計が必要になる場合は `orchestrator-coding` を使う。

## 関連ケース

- [case-02_scope-escalation.md](case-02_scope-escalation.md)（スキーマ全体設計へ波及した場合の切替提案との対比）
- [case-03_dialect-unknown-standalone.md](case-03_dialect-unknown-standalone.md)（方言判定材料が無い場合との対比）
