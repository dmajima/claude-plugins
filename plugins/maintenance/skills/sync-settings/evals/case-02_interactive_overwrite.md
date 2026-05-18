# Case 02: 対話モード + overwrite で同期承認

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Claude の設定を Git から同期して" |
| 引数 | `--repo https://github.com/myaccount/claude-settings`（または設定ファイルから取得） |
| フラグ | なし（既定 strategy = overwrite） |
| 既存状態 | `~/.claude/` 配下に既存設定あり、リモートに差分あり |

## 期待動作

### Phase 1〜4: 設定解決〜差分検出
- case-01 と同じ

### Phase 5: AskUserQuestion 確認
- 「{N} 件のファイル変更を ~/.claude/ に適用しますか？（戦略: overwrite）」
- 選択肢: 「同期する / ドライランで終了 / 戦略を変更して再表示 / キャンセル」
- ユーザが「同期する」を選択

### Phase 6: バックアップ取得
- `~/.claude/.local/plugins/maintenance/backup/YYYYMMDD_HHmmss/` に同期対象をコピー
- 認証情報（`credentials.json`）・`.env*` は除外

### Phase 7: 同期適用（overwrite）
- リモートで上書き、新規ファイルは追加
- `--prune` 未指定のため、ローカルのみのファイルは保持

### Phase 8: 設定保存
- `sync-config.json` に最新の repo / branch / targets / strategy / last_sync_at / history を記録

### Phase 9: サマリ出力
- Repo / Branch / Commit / 戦略 / バックアップパス / 適用件数 / 失敗件数

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | バックアップディレクトリ + 更新された `~/.claude/` 配下 + `sync-config.json` |
| 標準出力（要約） | 「===== 同期結果 =====」「適用件数: N 件」 |
| 終了状態 | 成功（exit 0）。失敗があれば exit 2 |

## 分岐の根拠

このケースが分岐するトリガーは AskUserQuestion の選択結果 = "同期する" + Strategy = "overwrite"（既定）である。

## 関連ケース

- `case-01_dry_run_first.md`（ドライラン）
- `case-03_interactive_cancel.md`（キャンセル選択）
- `case-05_merge_strategy.md`（merge 戦略）
