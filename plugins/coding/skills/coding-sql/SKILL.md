---
name: coding-sql
description: SQL の実装を広く受け入れられた慣習とプロジェクト独自規約（優先）で支援する言語スキル。MySQL / SQL Server / PostgreSQL の方言に対応。「SQL を書いて」「クエリを最適化して」「マイグレーションを作って」等で起動する。Use when writing or optimizing SQL. SKIP if 4+ files/full phases (orchestrator-coding), design-only (orchestrator-design), or ORM model code (coding-*).
---

# Coding SQL（SQL 言語スキル）

SQL の広く受け入れられた慣習（キーワード大文字・snake_case・明示的 JOIN・`SELECT *` 回避）・コード構造・方言知識（MySQL / SQL Server / PostgreSQL）を提供する言語スキル。
オーケストレーター参照と単独起動時の軽量実装フローに対応する。

## 責務

- SQL の慣習・イディオム・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- 方言差（識別子クォート・データ型・ページング・UPSERT・実行計画）の提供（[references/mysql.md](references/mysql.md) / [references/sqlserver.md](references/sqlserver.md) / [references/postgresql.md](references/postgresql.md)）
- 単独起動時の軽量実装フロー（方言判定 → 規約解決 → 実装 → 検証）
- 設計モードでのスキーマ・クエリ構造ガイダンス（テーブル設計・インデックス方針・マイグレーション設計）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| ORM（Prisma / EF Core / SQLAlchemy / Eloquent）の横断知識 | SSOT `../../references/frameworks/orm.md` |
| ORM モデル定義の言語側実装 | 各言語スキル（`coding-typescript` / `coding-csharp` / `coding-python` / `coding-php`） |
| 言語検出・SQL 方言判定マーカー | SSOT `../../references/skill-index.md` |

## トリガー条件（単独実行モード）

- 「SQL を書いて」「このクエリを最適化して」
- 「マイグレーションを作って」「この DDL をレビューして」

起動しないケース:

- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- ORM モデル定義の言語側実装（→ 該当する言語スキル: `coding-typescript` / `coding-csharp` / `coding-python` / `coding-php`）
- SQL 以外の言語（→ 該当する言語スキル）

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が SQL である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なれば該当言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と方言プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「SQL で〜を書いて」「このクエリを最適化して」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 方言の判定不能・規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## 実行フロー（単独実行モード）

1. **方言判定**: 対象 DBMS を特定する。判定材料は SSOT `../../references/skill-index.md`（および `../../references/language-detection.md` Step 3）に従い、ORM 設定の provider（`schema.prisma` の `provider` 等）・接続設定／ポート／コンテナイメージ（3306=MySQL / 1433=SQL Server / 5432=PostgreSQL）・既存 `.sql` の方言固有構文（`AUTO_INCREMENT` / `IDENTITY` / `SERIAL` 等）を走査する。特定できた方言のプロファイル（[references/mysql.md](references/mysql.md) / [references/sqlserver.md](references/sqlserver.md) / [references/postgresql.md](references/postgresql.md)）を適用対象に加える。判定不能なら共通規約のみで進め、方言固有構文が必要になった時点で `AskUserQuestion` で対象 DBMS を確認する（非対話モードでは共通構文に留めて報告する）
2. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`.sqlfluff`・`.editorconfig`・ORM スキーマ（`prisma/schema.prisma` 等）の命名／DDL 規約・`CLAUDE.md`・既存 `.sql` の書式／命名慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) の慣習を適用する
3. **ORM 確認**: `prisma/schema.prisma` / EF Core の `Migrations/` / Alembic / Laravel の `database/migrations/` 等の ORM が SQL を生成する場合、命名・DDL の一次情報源として SSOT `../../references/frameworks/orm.md` を併用する
4. **実装**: 解決した規約・方言プロファイル・構造ガイダンスに従って実装する。ユーザ入力を含むクエリは **必ずパラメータ化** する（文字列連結禁止）。破壊的なスキーマ変更は expand-contract で後方互換を保ち、大量更新・削除はバッチ分割する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
5. **検証**: 利用可能な範囲で検証する。`.sqlfluff` があれば `sqlfluff lint` / `sqlfluff fix`、実行計画は方言別コマンド（`EXPLAIN` 等）で確認する。DB 接続やツールが無く実行できない検証は SKIPPED として報告する
6. **報告**: 変更ファイル・適用した方言と規約の根拠（独自規約 or 慣習）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ、またはスキーマ全体設計に及ぶ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（慣習による上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）
- パラメータ化クエリ（SQL インジェクション防止）・マイグレーションの後方互換（expand-contract）・大量更新のバッチ分割など、[references/conventions.md](references/conventions.md) の安全事項を省略しない
- 方言が確定しない状態で方言固有構文を推測で使わない（共通構文に留め、必要時にユーザへ確認する）
- コミット・push・マイグレーションの実行はユーザの明示指示があるまで行わない

## 参照

| 用途 | ファイル |
|-----|---------|
| SQL 共通規約（慣習 / ツールチェーン / 典型エラー） | [references/conventions.md](references/conventions.md) |
| MySQL / MariaDB 方言 | [references/mysql.md](references/mysql.md) |
| SQL Server（T-SQL）方言 | [references/sqlserver.md](references/sqlserver.md) |
| PostgreSQL 方言 | [references/postgresql.md](references/postgresql.md) |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| 言語検出・SQL 方言判定マーカー（SSOT） | `../../references/skill-index.md` |
| ORM 横断知識（SSOT） | `../../references/frameworks/orm.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
