# Case 13: `/sync-map-set` 対話モード（引数なし・3 質問同時発火）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-map-set" |
| 引数（$ARGUMENTS） | 空文字 |
| 既定スコープ | project（カレントディレクトリ）|
| 既存状態（A） | カレントディレクトリの project マッピング不在 → 新規作成 |
| 既存状態（B） | カレントディレクトリの project マッピング存在 → 更新 |

## 期待動作

### Phase 1: モード判定 + 現在値取得
- `$ARGUMENTS` が空 → 対話モード
- `sync-mappings.ps1 -Action get -Scope project` でカレントディレクトリの現在のマッピングを取得

### Phase 2: AskUserQuestion 1 回で 3 質問同時発火

| 質問 | 1 つ目 | 残り | Other |
|-----|-------|-----|-------|
| remote_repo | 現在の URL`（現在の設定）` または 「カスタム URL を Other で入力」 | （URL 列挙不可のため省略可）| 自由入力 |
| remote_branch | 現在のブランチ`（現在の設定）` または `main（推奨）` | master / develop | 自由入力 |
| targets | 現在の targets`（現在の設定）` または `既定の project セット（推奨）` | 最小セット（settings.json のみ） | カンマ区切り自由入力 |

### Phase 3: バリデーション

Other 自由入力時:

- repo URL: `^(https?|git|ssh)://|^git@[A-Za-z0-9._\-]+:` にマッチしない or `-` で始まる → 再入力誘導
- branch: `^[A-Za-z0-9._/\-]+$` にマッチしない → 再入力誘導
- targets: カンマ区切り Trim 後の各要素が空でなければ受理

### Phase 4: 変更検出 + スクリプト実行

3 つの選択結果と現在値を比較し、**1 項目以上変更があれば** `sync-mappings.ps1 -Action set` を実行。全項目が現在値と同じなら `-Show` で現状表示のみ。

### Phase 5: 完了報告

更新後の設定を表示し、変更前→変更後の差分を提示。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| AskUserQuestion 発火回数 | 1 回（3 質問同時）|
| 生成/更新ファイル | `~/.claude/.local/plugins/maintenance/sync-mappings.json` |
| 標準出力 | 変更があった場合は `[updated] project マッピングを保存しました: <path>` + 新しい設定 |
| 終了状態 | 成功（exit 0）|

## 分岐の根拠

このケースが分岐するトリガーは `$ARGUMENTS` が空文字 である。

## 関連ケース

- `case-14_map_set_non_interactive.md`（引数あり）
- `case-15_map_list.md`（一覧表示）
- `case-16_map_delete_interactive.md`（対話削除）
