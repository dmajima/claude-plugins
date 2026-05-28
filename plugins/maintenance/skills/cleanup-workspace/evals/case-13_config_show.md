# Case 13: 閾値設定の表示（`/cleanup-config` 引数なし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/cleanup-config" |
| 引数 | なし（または `--show`） |
| フラグ | なし |
| 既存状態 | `~/.claude/.local/plugins/maintenance/cleanup-config.json` の有無は問わない |

## 期待動作

### Phase 1: スクリプト起動
- `cleanup-config.sh` が引数なし or `-Show` で起動

### Phase 2: 設定読み込み
- 設定ファイル存在: 既存値を読み込み、不足フィールドは出荷時デフォルトで補完
- 設定ファイル不在: 出荷時デフォルトを表示（ファイル作成はしない）

### Phase 3: 表示
- Config file パス
- 各フィールド: `version` / `default_days` / `default_keep_recent` / `default_scope` / `active_session_minutes` / `atime_strategy`

### Phase 4: 終了
- 変更なし、exit 0

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（設定ファイルが既に存在する場合は更新もしない）|
| 標準出力（要約） | 「===== cleanup-workspace 閾値設定 =====」 + 各フィールド値 |
| 終了状態 | 成功（exit 0）|

## 分岐の根拠

このケースが分岐するトリガーは 引数 `--Show` または引数なし である。

## 関連ケース

- `case-14_config_set.md`（設定変更）
- `case-15_progress_md_fallback.md`（atime 戦略のフォールバック）
