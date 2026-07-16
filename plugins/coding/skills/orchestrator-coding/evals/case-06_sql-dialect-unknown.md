# Case 06: SQL 方言判定不能時の確認

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この集計クエリを月別にグループ化するよう修正して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `queries/monthly-report.sql` のみのリポジトリ。ORM 設定・docker-compose・接続文字列が無く、既存 SQL にも方言固有構文が無い |

## 期待動作

### Phase 2: Analyze
- `.sql` から SQL を検出。方言判定材料（ORM provider / ポート / イメージ / 方言固有構文）を走査するが特定できない
- `coding-sql` の `conventions.md`（共通規約）のみを適用し、その旨を記録

### Phase 4: Implement
- 方言共通の構文範囲で修正を試みる
- 日付関数（月別グループ化に必要な `DATE_FORMAT` / `FORMAT` / `date_trunc` 等）など **方言固有構文が必要になった時点** で `AskUserQuestion` により対象 DBMS（MySQL / SQL Server / PostgreSQL）を確認
- 回答された方言リファレンス（例: `coding-sql` の `postgresql.md`）を追加適用して実装
- 方言確定後の適用結果を具体化（例: PostgreSQL と回答された場合）:
  - `coding-sql` の `postgresql.md` を追加適用（適用スキルを共通規約 + postgresql.md へ拡張）
  - 月別集計を `date_trunc('month', <日付列>)` によるグループ化で実装
  - `impact-analysis.md` の適用スキル欄・規約サマリに「方言 = PostgreSQL 確定、postgresql.md 追加適用」を追記（当初の共通規約のみ適用から更新）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 方言固有構文が必要な場合のみ AskUserQuestion 発火 |
| 生成ファイル | impact-analysis.md（共通規約のみ適用 → 方言確定後に追記） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは SQL 方言の判定可否 = 不能 である。language-detection.md Step 3「判定できない場合は共通規約のみ適用し、必要時にユーザ確認」が適用される。

## 関連ケース

- `case-05_monorepo-multi-language.md`（ORM 設定から方言が判定できる場合）
- `case-07_non-interactive.md`（非対話モードでは共通構文に留めて報告）
