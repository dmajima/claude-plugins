# Case 04: 非対話モードでの単独実行

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この集計クエリに期間フィルタを追加して --non-interactive」 |
| 引数 | タスク説明 |
| フラグ | `--non-interactive` |
| 既存状態 | `docker-compose.yml` に `postgres:16`（ポート 5432）があり **方言は PostgreSQL と特定可能**。期間フィルタの境界（開始・終了を含むか）が未指定。ユーザの直接依頼で `coding-sql` を単独起動（orchestrator を経由しない） |

## 期待動作

単独実行モードの実行フロー 6 段を、実行モード判定表の非対話行（`--non-interactive` → 確認をスキップし、最も保守的な解釈を採用して進行する。採用した判断は報告に記録する）に従って実施する。

### 全ステップ共通
- `AskUserQuestion` を発火させず、不明点（境界の含む/含まない）は最も保守的な解釈を採用して進行する
- 採用したデフォルト判断を報告に必ず記録する

### ステップ1: 方言判定
- 判定材料（ポート 5432 / `postgres` イメージ）から PostgreSQL と特定し、[references/postgresql.md](../references/postgresql.md) を適用対象に加える（方言が特定できるため case-03 の「判定不能」分岐とは異なる）

### ステップ2〜3: 規約解決・ORM 確認
- 独自規約（`.sqlfluff`・`.editorconfig`・既存 `.sql` の書式/命名慣習）を走査する
- 規約に矛盾があっても確認せず、SSOT `../../../references/conventions-resolution.md` の優先順位で機械的に解決し、採用理由を記録する

### ステップ4: 実装
- 期間の境界は最も安全側の保守的判断（開始・終了とも半開区間 `>= start AND < end` など既存クエリの傾向に合わせる）を採用し、採用理由を記録する
- ユーザ入力を含む値は **必ずパラメータ化** する（文字列連結禁止）など [references/conventions.md](../references/conventions.md) の安全事項を維持する

### ステップ5〜6: 検証・報告
- 利用可能な範囲で検証する（`.sqlfluff` があれば `sqlfluff lint`、DB 接続不能な検証は SKIPPED）
- 採用したデフォルト判断・適用方言（PostgreSQL）と規約の根拠・検証結果を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 適用方言 | PostgreSQL（判定材料から特定） |
| ユーザへの確認 | 0 回（AskUserQuestion 不発火） |
| 生成ファイル | リポジトリへのコード変更（パラメータ化済み）。報告にデフォルト判断（境界の解釈）の記録あり |
| 終了状態 | 成功（保守的解釈で完了） |

## 分岐の根拠

このケースが分岐するトリガーは フラグ = `--non-interactive`（かつ方言は判定可能） である。
実行モード判定表の非対話行「確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録）」を単独実行フロー全体に適用する。方言が特定できるため方言確認は発生しない。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（対話モードで方言判定できる基本フローとの対比）
- [case-03_dialect-unknown-standalone.md](case-03_dialect-unknown-standalone.md)（**方言判定不能** かつ非対話時は共通構文に留める分岐。本ケースは方言判定可能な点が対照的）
- [case-05_convention-conflict.md](case-05_convention-conflict.md)（対話モードで検出規約とユーザ指示が矛盾し AskUserQuestion が発火するケースとの対比）
