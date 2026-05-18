# Case 14: `/sync-map-set` 非対話モード（引数あり）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/sync-map-set --repo https://github.com/user/claude-settings --branch main --scope global" |
| 引数（$ARGUMENTS） | `--repo https://github.com/user/claude-settings --branch main --scope global` |
| 既存状態 | 任意（新規・更新どちらでも）|

## 期待動作

### Phase 1: 引数解析
- `--scope global` を採用
- `--repo` / `--branch` を引数からそのまま採用
- `--targets` 省略時は global 既定セット（settings.json, skills, rules, agents, hooks, CLAUDE.md）

### Phase 2: バリデーション

- repo URL: 形式チェック（プロトコル正規表現 + `-` プレフィクス拒否）
- branch: 許可文字チェック
- 失敗時はエラーで終了（exit 1）

### Phase 3: 保存

`sync-mappings.json` の global フィールドに新マッピング保存。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成/更新ファイル | `~/.claude/.local/plugins/maintenance/sync-mappings.json` |
| 標準出力 | `[updated] global マッピングを保存しました` + 新しい設定 |
| 終了状態 | 成功（exit 0）|

## バリデーション失敗ケース

| 引数 | エラー |
|-----|-------|
| `--repo ftp://...` | `Repo URL の形式が無効です（https/http/git/ssh/git@host: のみ許可）` exit 1 |
| `--repo "--upload-pack=..."` | `Repo URL は '-' で始められません（git CLI のオプションとして解釈される危険）` exit 1 |
| `--branch "main$bad"` | `Branch 名に無効な文字が含まれています` exit 1 |

## 分岐の根拠

このケースが分岐するトリガーは `$ARGUMENTS` が非空 である。

## 関連ケース

- `case-13_map_set_interactive.md`（対話モード）
