# coding-sql スキル

SQL（クエリ・DDL・マイグレーション）の実装・最適化を、広く受け入れられた慣習とプロジェクト独自規約に基づいて支援する言語スキル。MySQL / SQL Server / PostgreSQL の方言差を吸収し、`orchestrator-coding` / `orchestrator-design` からの参照と単独起動の両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません（スキルの動作は `SKILL.md` と `references/` 配下が定義します）。

## 使い方

### 利用モード

| モード | 起動のされ方 | 動作 |
|-------|------------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` から呼ばれる | 規約・方言プロファイルを判定基準として提供（フェーズ制御はしない） |
| 単独実行モード | 下記トリガーフレーズでユーザが直接依頼 | 方言判定 → 規約解決 → 実装 → 検証の軽量フローを実施 |

### トリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「この集計クエリを月別に最適化して」 | 単独実行モード（方言判定 → 実装 → 実行計画確認） |
| 「ユーザテーブルに列を追加するマイグレーションを作って」 | 単独実行モード（後方互換を意識した DDL） |
| 「この DDL をレビューして」 | 規約・安全性の観点でレビュー |

## 対応フレームワーク

方言判定（ポート / イメージ / ORM provider / 既存 `.sql` の構文）で対象 DBMS を特定し、該当プロファイルを適用する。判定できない場合は共通規約のみで進め、方言固有構文が必要になった時点でユーザに確認する。

| 方言 | プロファイル | 主な検出マーカー |
|------|-------------|----------------|
| MySQL / MariaDB | `references/mysql.md` | ポート 3306 / `mysql`・`mariadb` イメージ |
| SQL Server（T-SQL） | `references/sqlserver.md` | ポート 1433 / `mssql` イメージ / `Server=` 接続文字列 |
| PostgreSQL | `references/postgresql.md` | ポート 5432 / `postgres` イメージ |

ORM（Prisma / EF Core / SQLAlchemy / Eloquent）の横断知識はプラグイン SSOT `../../references/frameworks/orm.md` を参照する（SQL を生成する場合の命名・DDL の一次情報源）。

## カスタマイズ

| やりたいこと | 方法 |
|-------------|------|
| SQL 共通の慣習・ツールチェーンを調整 | `references/conventions.md` を編集 |
| 方言固有の規約を調整 | `references/mysql.md` / `references/sqlserver.md` / `references/postgresql.md` を編集 |
| 新しい方言への対応 | プラグイン SSOT `../../references/language-skill-template.md` に従い方言プロファイルを追加し、`../../references/skill-index.md` に検出マーカーを登録 |

## ファイル構成

```text
skills/coding-sql/
├── SKILL.md                    # スキル定義（Claude が実行時に参照）
├── README.md                   # 本ファイル（人間向け）
└── references/
    ├── conventions.md          # SQL 共通規約（慣習・ツールチェーン・典型エラー）
    ├── mysql.md                # MySQL / MariaDB 方言
    ├── sqlserver.md            # SQL Server（T-SQL）方言
    └── postgresql.md           # PostgreSQL 方言
```

言語検出・規約解決・ORM 横断知識・設計原則・成果物テンプレートはプラグイン直下 `references/`（SSOT）を参照する。
