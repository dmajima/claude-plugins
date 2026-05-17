# Case 14: 閾値設定の変更（`/cleanup-config --set-days 60`）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/cleanup-config --set-days 60 --set-keep-recent 5 --set-scope global" |
| 引数 | `--set-days 60 --set-keep-recent 5 --set-scope global` |
| フラグ | なし |
| 既存状態 | 設定ファイルの有無は問わない |

## 期待動作

### Phase 1: 引数解析
- `-SetDays 60`、`-SetKeepRecent 5`、`-SetScope global` を検出

### Phase 2: 設定読み込み + 更新
- 既存設定（または出荷時デフォルト）を読み込み
- `default_days = 60`、`default_keep_recent = 5`、`default_scope = global` に更新
- `[updated]` ログを各フィールドごとに出力

### Phase 3: 保存
- `~/.claude/.local/plugins/maintenance/cleanup-config.json` に書き込み
- 親ディレクトリが不在なら自動作成

### Phase 4: 更新後の設定を表示
- 「===== cleanup-workspace 閾値設定 =====」 + 各フィールド値

### Phase 5: 終了
- exit 0

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成/更新ファイル | `~/.claude/.local/plugins/maintenance/cleanup-config.json` |
| 標準出力（要約） | `[updated] default_days = 60` 等の更新ログ + 更新後の設定全体表示 |
| 終了状態 | 成功（exit 0）|

## 分岐の根拠

このケースが分岐するトリガーは `-SetDays` / `-SetKeepRecent` / `-SetScope` 等の更新フラグが指定された場合 である。

## バリデーション

| 入力 | 動作 |
|-----|------|
| `--set-days -1` | エラー（0 以上の整数を要求）、exit 1 |
| `--set-keep-recent -1` | エラー、exit 1 |
| `--set-scope invalid` | PowerShell `[ValidateSet]` でエラー、exit 1 |
| `--set-active-minutes 0` | エラー（1 以上の整数を要求）、exit 1 |

## 関連ケース

- `case-13_config_show.md`（設定表示）
- `--reset --yes` での出荷時デフォルトリセット（暗黙的にカバー）
