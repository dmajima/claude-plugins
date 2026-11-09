# Case 47: PreToolUse hook — シェルのコマンドに認証情報系ファイルに似た語 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Bash","tool_input":{"command":"jq -r '.key' data.json"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"Bash","tool_input":{"command":"cat .env.example"}}` |
| stdin (Claude → hook) 例 3 | `{"tool_name":"Bash","tool_input":{"command":"ls plugins/credentials-manager/skills"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 手掛かりの語（`.key` / `.env` / `credential`）を含むため、トークンごとにファイル系ツールと同じ規則で判定する
- 例 1: `.key` は拡張子の前に語幹が無い（jq のフィルタ）ため、秘密鍵の拡張子として扱わない
- 例 2: `.env.example` は除外リスト（`.example` / `.sample` / `.template` / `.dist` / `.test` / `.spec`）に該当する
- 例 3: `plugins/credentials-manager/skills` は、ファイル名の完全一致・拡張子・特殊ディレクトリのいずれにも該当しない（語の一部の一致では判定しない）
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

シェルのコマンドは、ファイル系ツールのパスより多様な語を含む。手掛かりの語の部分一致で通知すると、
`credentials-manager` のようなパスや jq のフィルタで誤発火するため、トークンをファイル名として判定する。
なお `echo ".env" >> .gitignore` のように `.env` を指すトークンは、操作の種類によらず通知される（既知の誤検出）。

## 関連ケース

- `case-46_pretooluse_shell_credential_file_trigger.md`（対比：trigger するケース）
- `case-22_pretooluse_read_env_example_noop.md`（同じ除外リストを Read ツールで判定するケース）
