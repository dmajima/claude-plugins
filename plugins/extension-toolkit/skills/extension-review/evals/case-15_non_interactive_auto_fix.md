# Case 15: --non-interactive + --auto-fix 同時指定（CI 自動レビュー + 軽微修正適用）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter --non-interactive --auto-fix` でレビュー" |
| 引数 | `code-formatter` |
| フラグ | `--non-interactive` + `--auto-fix` |
| 既存状態 | スキル存在、軽微指摘（パスポータビリティ NG / `§` 記号 / プレースホルダ等）あり |

## 期待動作

### Phase 1: モード判定

両フラグ検出 → **非対話 + 自動修正モード**。
ユーザ確認は **一切行わない**（`AskUserQuestion` 呼び出しなし）。

### Phase 2: フレッシュ起動でレビュー実施

[`../references/team-selection.md`](../references/team-selection.md) に従い `skill-review-team` をフレッシュインスタンスで並列起動（ADR-021 / [`../../../references/checklists/review-freshness.md`](../../../references/checklists/review-freshness.md) 準拠）。

### Phase 3: 軽微指摘の自動修正適用

自動修正可能な指摘のみを **対話確認なしで適用**:

| 指摘種別 | 自動修正 |
|---------|---------|
| `§` 記号 | 「セクション」「節」等に置換 |
| 明らかな NG パス（個人ホームディレクトリ等） | `${CLAUDE_PLUGIN_ROOT}` への置換提案 |
| プレースホルダ残存 | 修正不可、警告のみ記録 |
| 構造的問題 | 修正不可、警告のみ記録 |
| **セキュリティ指摘 / シークレット混入** | **修正対象外**（fail-safe、ユーザ確認なしで自動適用しない） |

### Phase 4: 結果統合

| 項目 | 動作 |
|-----|------|
| 自動修正済み件数 | 標準出力に件数 + 種別を提示 |
| 修正不可件数 | 標準出力に Critical/High/Medium 別に件数 |
| Critical/High 残存 | エラー扱い（exit 1）、修正不可指摘の詳細を提示 |

### Phase 5: 引き渡し（非対話）

| 項目 | 動作 |
|-----|------|
| 標準出力 | 修正済み一覧 + 残存指摘 + 総合判定 |
| ユーザ対話 | 発生しない |
| 終了状態 | Critical/High なし → 0、あり → 1 |

`AskUserQuestion` は **一切呼び出さない**。CI / 自動化スクリプトでの利用を想定。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | 自動修正対象の `*.md` ファイル（差分は標準出力に提示）|
| 標準出力 | 修正済み件数 + 残存指摘 + 総合判定 |
| 終了状態 | 残存指摘の重大度に応じて 0 または 1 |

## 分岐の根拠

`--non-interactive` + `--auto-fix` 両方検出 → CI 向け自動修正フロー。
`--non-interactive` 単独（case-12）は質問なしで結果のみ提示、`--auto-fix` 単独（case-04）は対話確認しつつ自動修正適用、本ケースは両者の同値積（質問なし + 自動修正適用）。

## 関連ケース

- `case-04_auto_fix.md`（対話モード + 自動修正）
- `case-12_non_interactive.md`（非対話モード、修正なし）
