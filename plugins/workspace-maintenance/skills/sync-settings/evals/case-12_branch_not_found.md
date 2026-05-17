# Case 12: ブランチ不在エラー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "develop ブランチから設定を同期して" |
| 引数 | `--repo https://github.com/myaccount/claude-settings --branch develop` |
| フラグ | なし |
| 既存状態 | リモートリポジトリに `develop` ブランチが存在しない |

## 期待動作

### Phase 1: 引数解析
- `--branch develop` を採用
- Branch 名のフォーマットチェック（`^[A-Za-z0-9._/\-]+$`）は合格

### Phase 2: Git clone / fetch 試行
- `git clone --depth 1 --branch develop ...` または `git fetch --depth 1 origin develop` 実行
- exit code が 0 でない（ブランチ不在のエラー）

### Phase 3: エラーハンドリング
- `Write-Error "Git clone 失敗: exit {N}"` または `Write-Error "Git fetch 失敗"` を出力
- 同期処理は実行されない（exit 1）
- バックアップ取得もしない
- `sync-config.json` も更新しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 同期適用 | なし |
| 標準出力（要約） | Git CLI のエラー出力 + 「Git clone 失敗」「Git fetch 失敗」 |
| 終了状態 | 失敗（exit 1） |

## 分岐の根拠

このケースが分岐するトリガーは Git CLI の `$LASTEXITCODE != 0` である。

## ユーザのリカバリ手順

1. リモートリポジトリの利用可能ブランチを確認
   ```bash
   git ls-remote --heads https://github.com/myaccount/claude-settings
   ```
2. 正しいブランチ名を `--branch` で指定して再実行
3. または `sync-config.json` の `last_branch` を修正

## 関連エラー

| エラー種別 | 期待挙動 |
|---------|---------|
| ブランチ不在 | 本ケース |
| リポジトリ URL 不正（HTTP 404） | 同様に Git clone 失敗 → exit 1 |
| 認証エラー（プライベート repo） | Git clone 失敗 + `credentials-manager` 連携案内 |
| ネットワークエラー | Git clone 失敗 + 再試行案内 |

## 関連ケース

- `case-01_dry_run_first.md`（正常な clone）
- `case-11_backup_failure.md`（別種別の中止エラー）
