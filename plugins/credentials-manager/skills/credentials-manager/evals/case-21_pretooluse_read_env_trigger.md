# Case 21: PreToolUse hook — Read .env → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Read","tool_input":{"file_path":"/repo/.env"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Read`
- `Read|Write|Edit|MultiEdit|NotebookEdit` 分岐に入り `file_path` を抽出

### Phase 2: ファイルパス判定

- `detect_credential_file` が basename `.env` を検出
- 完全一致 `.env` → 認証情報系ファイル該当
- `set_reason "環境変数定義ファイル (.env) を操作"` に到達

### Phase 3: Claude へ通知

- `additionalContext` で credentials-manager 最優先起動を要求

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（`.env` 検出 reason 含む） |
| 終了コード | 0 |

## 分岐の根拠

認証情報系ファイルパス検出分岐の代表ケース。`.env.<name>` も同分岐（`.env.example` 等の除外との境界は case-22）。

## 関連ケース

- `case-22_pretooluse_read_env_example_noop.md`（除外パターンの境界）
- `case-23_pretooluse_write_secret_trigger.md`（コンテンツ検出側）
