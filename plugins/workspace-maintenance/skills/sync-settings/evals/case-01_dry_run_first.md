# Case 01: 初回ドライランで差分表示のみ

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/myaccount/claude-settings から設定を dry-run で確認して" |
| 引数 | `--repo https://github.com/myaccount/claude-settings --branch main --dry-run` |
| フラグ | `--dry-run` |
| 既存状態 | `sync-config.json` 不在（初回実行）。`~/.claude/settings.json` / `~/.claude/rules/` 等が存在 |

## 期待動作

### Phase 1: 設定解決
- `--repo` 引数を採用
- `--branch main`、既定 targets、既定 strategy（overwrite）

### Phase 2: リポジトリ取得
- `~/.claude/.local/plugins/workspace-maintenance/repo/` に新規 `git clone --depth 1 --branch main`

### Phase 3: 同期対象解決
- 既定 6 ターゲット（settings.json, skills, rules, agents, hooks, CLAUDE.md）について実在確認
- 不在のものはスキップ + 警告

### Phase 4: 差分検出
- リモートとローカルを比較し、[ADD] / [MOD] / [DEL]（`--prune` 時のみ）に分類
- 認証情報・Git メタデータは除外

### Phase 5: 差分表示
- 件数サマリ + 各エントリ表示
- 「(dry-run) 実適用は行いません。」を出力

### Phase 6: 終了
- AskUserQuestion 発火なし
- バックアップなし
- 同期適用なし

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | クローン先のみ（`repo/` 配下） |
| ファイル変更 | なし |
| 標準出力（要約） | 「===== 差分検出 =====」「(dry-run) 実適用は行いません。」 |
| 終了状態 | 成功（exit 0） |

## 分岐の根拠

このケースが分岐するトリガーは `--dry-run` フラグ = 指定あり である。

## 関連ケース

- `case-02_interactive_overwrite.md`（対話モードでの実適用）
- `case-09_config_reuse.md`（2 回目以降の設定再利用）
