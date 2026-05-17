# Case 09: 設定ファイル再利用（2 回目以降）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Claude の設定を Git から同期して" |
| 引数 | なし（または `--dry-run` のみ） |
| フラグ | なし |
| 既存状態 | `~/.claude/.local/plugins/maintenance/sync-config.json` に前回の `last_repo` / `last_branch` / `last_strategy` が保存されている |

## 期待動作

### Phase 1: 設定解決
- `--repo` 引数不在
- `sync-config.json` から `last_repo` / `last_branch` / `last_targets` / `last_strategy` を取得
- ユーザに「Repo を設定ファイルから取得: {repo}」と通知

### Phase 2 以降: 通常フロー
- 取得した設定で clone / 差分検出 / 同期適用

### Phase 8: 設定保存
- `sync-config.json` を更新
- `history[]` 配列に今回の sync 情報を先頭追加（最大 10 件保持）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常の同期成果物 + 更新された `sync-config.json` |
| 標準出力（要約） | 「Repo を設定ファイルから取得: {repo}」 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--repo` 引数不在 + `sync-config.json` 存在 + `last_repo` フィールドあり である。

## 設定ファイルがない場合の挙動

| 状況 | 動作 |
|-----|------|
| 設定ファイル不在 + `--repo` 不在 + 対話モード | テキスト対話で repo URL を収集（AskUserQuestion ではなく自由入力） |
| 設定ファイル不在 + `--repo` 不在 + 非対話モード | エラーで終了 |

## 関連ケース

- `case-01_dry_run_first.md`（初回・引数指定）
- 設定ファイルに `history` が蓄積される動作
