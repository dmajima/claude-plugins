# Case 04: 非対話モード (--yes)

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "--yes 指定で自動同期して" |
| 引数 | `--repo https://github.com/myaccount/claude-settings --yes` |
| フラグ | `--yes` |
| 既存状態 | リモートに差分あり |

## 期待動作

### Phase 1〜4: 設定解決〜差分検出
- 通常通り

### Phase 5: AskUserQuestion スキップ
- `--yes` のため AskUserQuestion は発火しない
- 差分表示直後にバックアップ取得 → 同期適用に進む

### Phase 6: バックアップ取得
- `--no-backup` 未指定のため必須実施

### Phase 7: 同期適用
- 既定 strategy = overwrite で適用

### Phase 8: 設定保存
- `sync-config.json` 更新

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | バックアップ + 更新された `~/.claude/` + `sync-config.json` |
| 標準出力（要約） | 差分一覧直後に「===== 同期結果 =====」 |
| 終了状態 | 成功（exit 0）。失敗があれば exit 2 |

## 分岐の根拠

このケースが分岐するトリガーは `--yes` フラグ = 指定あり である。

## 安全装置

- バックアップは省略不可（`--yes` でも実施）
- 認証情報除外は省略不可
- `--yes` + `--dry-run` の場合は `--dry-run` 優先（警告ログ）
- `--yes` + `--no-backup` の場合はバックアップなしで実行（強い警告ログ）

## 関連ケース

- `case-02_interactive_overwrite.md`（対話モードの承認）
- `case-10_no_backup.md`（バックアップ省略）
