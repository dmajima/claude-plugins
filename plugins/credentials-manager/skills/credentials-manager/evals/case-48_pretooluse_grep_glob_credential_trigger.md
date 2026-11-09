# Case 48: PreToolUse hook — Grep / Glob で認証情報系ファイルを検索 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Grep","tool_input":{"pattern":"API_KEY","path":"/repo/.env"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"Glob","tool_input":{"pattern":"**/*.pem"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: フックの起動とツール種別判定

- `hooks.json` の matcher が `Grep` / `Glob` を含むため、フックが起動する
- `tool_name` → `Grep` / `Glob` の分岐に入る

### Phase 2: 検索対象の判定

- Grep は `path` と `glob`、Glob は `path` と `pattern` を、ファイル系ツールと同じ規則（`credential_file_reason`）で判定する
- 例 1: `path` が `.env` → `REASON` = `Grep で環境変数定義ファイル (.env) を操作`
- 例 2: `pattern` の末尾が `*.pem`（ワイルドカード付きの拡張子）→ `REASON` = `Glob で秘密鍵 / 証明書らしい拡張子のファイル (*.pem) を操作`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動と、値をマスクして扱うことを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に上記の理由文を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

Grep は該当したファイルの内容（`.env` の値等）を出力できるため、Read と同じく認証情報系ファイルへの操作として扱う。
Glob はファイル名の一覧だけを返すが、認証情報系ファイルを探す操作として同じ規則で通知する。
`**/.env*` / `**/credentials*.json` のようなワイルドカードは、ワイルドカードを除いた名前で判定する。
Grep の `pattern` は検索する正規表現であり、ファイルを指さないため判定しない。

## 関連ケース

- `case-21_pretooluse_read_env_trigger.md`（同じファイルを Read ツールで読むケース）
- `case-49_pretooluse_grep_glob_noop.md`（対比：no-op のケース）
