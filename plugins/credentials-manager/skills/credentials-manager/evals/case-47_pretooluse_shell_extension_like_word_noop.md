# Case 47: PreToolUse hook — シェルのコマンドに拡張子に似た語（jq のパス・変数のプロパティ）→ no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Bash","tool_input":{"command":"jq -r '.key' data.json"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"Bash","tool_input":{"command":"jq -r '.data.key' data.json"}}` |
| stdin (Claude → hook) 例 3 | `{"tool_name":"PowerShell","tool_input":{"command":"Get-ChildItem Env: \| ForEach-Object { $_.Key }"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash` / `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 手掛かりの語（`.key`）を含むため、トークンごとにファイル系ツールと同じ規則（`credential_file_reason` をシェルのトークンとして呼ぶ）で判定する
- 例 1: `.key` は拡張子の前に語幹が無いため、秘密鍵の拡張子として扱わない
- 例 2: `.data.key` は `.` で始まり、パスの区切りを含まないため、jq のパスとみなし、拡張子では判定しない
- 例 3: PowerShell の `$_.Key` は `$` で始まり、パスの区切りを含まないため、変数のプロパティとみなし、拡張子では判定しない（Bash の `$name.key` は変数 + 拡張子のファイル名として判定する）
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

シェルのコマンドには、jq のフィルタや PowerShell のプロパティ参照のように、ファイル名ではない `.key` が頻出する。
拡張子だけで通知すると、`.key` を読むたびに誤って通知されるため、語幹の有無と先頭の文字で区別する。
ファイル系ツールのパス（`Read` の `/repo/.data.key` 等）は実在するファイルを指すため、この例外を適用しない。
パスの区切りを含むもの（`./.server.key` / `$HOME/certs/server.pem`）と、Bash の `$name.pem` は通知する。語幹のあるプロパティ（`console.log(c.key)`）は通知される（既知の誤検出）。

## 関連ケース

- `case-46_pretooluse_shell_credential_file_trigger.md`（対比：trigger するケース）
- `case-54_pretooluse_shell_env_example_noop.md`（除外リストに該当する語のケース）
- `case-55_pretooluse_shell_partial_word_noop.md`（語の一部だけが一致するケース）
