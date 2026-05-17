# Case 05: --scope all（既定）正常系

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all`（引数なし）または `/update-all --scope all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `all` |
| 既存状態 | user 2 件 / project 1 件 / local 1 件のプラグイン、マーケットプレイス 3 件 |

## 期待動作

### Phase A-0-1: 引数バリデーション
- `scope` を `all` と確定（引数なしの既定値）

### Phase A: 対象収集（全スコープ）
- `~/.claude/settings.json`（user）
- `<project>/.claude/settings.json`（project）
- `<project>/.claude/settings.local.json`（local）
- すべてから `enabledPlugins` のみ Grep で抽出

### Phase B: マーケットプレイス更新
- 全マーケットプレイス（3 件）を `claude plugin marketplace update <name>` で順次更新

### Phase C → D → E: 各スコープのプラグイン更新
- C: User 2 件
- D: Project 1 件（projectPath がカレントと一致）
- E: Local 1 件

### Phase F: 結果報告
- スコープ別の詳細テーブル（user / project / local 全件）
- マーケットプレイス更新サマリ
- 全体サマリ（成功 / 失敗 / Skipped / Missing の区分集計）

### Phase G: 失敗対応
- Failed が出た場合のみ AskUserQuestion

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新 3 + Plugin 更新 4 |
| 標準出力（要約） | 「scope: all」「user: 2 / project: 1 / local: 1」 |
| 終了状態 | 全件成功なら exit 0 |

## 分岐の根拠

このケースが分岐するトリガーは `scope = all`（既定）である。

## 関連ケース

- `case-01_dry_run.md`（同じ scope だが mode = dry-run）
- `case-02_scope_user.md`〜`case-04_scope_local.md`（個別スコープ）
- `case-08_circuit_breaker.md`（Phase B 失敗時のサーキットブレーカー連動）
