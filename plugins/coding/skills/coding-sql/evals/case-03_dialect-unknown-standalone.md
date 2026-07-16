# Case 03: 単独実行モードで方言判定材料なし

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この集計クエリを月別にグループ化するよう書いて」 |
| 引数 | なし |
| フラグ | なし（対話モード）／ 一部検証は `--non-interactive` 併記時の挙動も定義 |
| 既存状態 | `queries/` 配下に `.sql` が数本あるのみ。ORM 設定・docker-compose・接続文字列が無く、既存 SQL にも方言固有構文が無い。ユーザの直接依頼で `coding-sql` を単独起動（orchestrator を経由しない） |

## 期待動作

単独実行モードの実行フロー 6 段のうち、方言判定と実装が焦点になる。

### ステップ1: 方言判定
- SSOT `../../../references/skill-index.md`（および `../../../references/language-detection.md` Step 3）に従い判定材料（ORM provider・ポート・イメージ・既存 `.sql` の方言固有構文）を走査するが特定できない
- 判定不能のため方言プロファイル（mysql.md / sqlserver.md / postgresql.md）は適用せず、[references/conventions.md](../references/conventions.md) の共通規約のみで進める旨を記録

### ステップ2〜3: 規約解決・ORM 確認
- 独自規約（`.sqlfluff` / `.editorconfig` / 既存 `.sql` の書式・命名慣習）を走査。ORM は該当なし

### ステップ4: 実装（方言固有構文が必要になる分岐）
- 方言共通の構文範囲で実装を試みる
- 月別グループ化に必要な日付関数など、方言固有構文（MySQL: `DATE_FORMAT` / SQL Server: `FORMAT` / PostgreSQL: `date_trunc`）が必要になった時点で分岐する
  - 対話モード: `AskUserQuestion` で対象 DBMS（MySQL / SQL Server / PostgreSQL）を確認し、回答された方言リファレンス（例: `postgresql.md`）を追加適用して実装
  - 非対話モード（`--non-interactive`）: 方言固有構文を推測で使わず、共通構文に留める。方言確定が必要な箇所は保留とし、その旨と確定後に必要な対応を報告に記録

### ステップ5〜6: 検証・報告
- 検証は共通範囲で可能なもののみ（方言指定が要るものは SKIPPED）
- 方言未確定である旨・共通規約のみ適用・保留した方言固有部分を報告

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 適用方言 | なし（未確定。共通規約のみ） |
| ユーザへの確認 | 対話モードでは方言固有構文が必要になった時点でのみ AskUserQuestion 発火。非対話モードでは 0 回 |
| 生成ファイル | リポジトリへのコード変更（共通構文の範囲、または方言確定後に完成） |
| 終了状態 | 成功（対話で方言確定 or 非対話で共通構文に留めて報告） |

## 分岐の根拠

このケースが分岐するトリガーは SQL 方言の判定可否 = 不能 かつ 起動経路 = 単独実行モード である。
`language-detection.md` Step 3「判定できない場合は共通規約のみ適用し、必要時にユーザ確認（非対話では共通構文に留める）」を、`coding-sql` の単独実行フロー内で適用する。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（方言が判定できる場合との対比）
- `../../orchestrator-coding/evals/case-06_sql-dialect-unknown.md`（orchestrator 経由の同種ケース）。**コードパスが異なる**: case-06 はオーケストレーターの Phase 2 Analyze で方言判定・Phase 4 Implement で AskUserQuestion が発火し、判定結果は `impact-analysis.md` 等のフェーズ成果物へ記録される。本ケースは `coding-sql` 単独実行フローのステップ1「方言判定」→ ステップ4「実装」で発火し、言語スキルが直接ユーザへ確認・報告する（フェーズ成果物を生成しない）。
