# Case 44: PreToolUse hook — 語の途中の sk- / メタデータだけに含まれる語 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Bash","tool_input":{"command":"cat docs/task-management-system.md"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"Write","cwd":"C:/work/task-management-system-v2","tool_input":{"file_path":"/repo/a.txt","content":"hello"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- 例 1: `tool_name` → `Bash`、`tool_input.command` 抽出
- 例 2: `tool_name` → `Write`、`tool_input` の文字列（`/repo/a.txt` と `hello`）を抽出。`cwd` は照合の対象にしない

### Phase 2: パターン照合

- 例 1: `task-management-system` の中の `sk-` で始まる部分は、直前が英字（`a`）のため既知のトークン形式に一致しない
- 例 2: `tool_input` の文字列にはパターンが無い。`cwd` の語は照合しない
- いずれも `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

既知のトークン形式（`sk-` / `ghp_` 等）は、左側に英数字・`_`・`-` が無いことを条件にする。条件が無いと、
`task-` `flask-` `desk-` のような語を含むパスや文章で通知され、リポジトリ名に該当語があると Write / Edit のたびに通知される。
`token=sk-...` / `"sk-..."` / 行頭の `sk-...` は検出する（`case-23`・`case-36`）。エスケープした改行・タブ（`\n` / PowerShell の `` `n `` 等）と
URL エンコード（`%3D` 等）の直後も、英数字が続いていても境界として扱い、検出する。

## 関連ケース

- `case-23_pretooluse_write_secret_trigger.md`（対比：コンテンツのシークレットで trigger）
- `case-36_pretooluse_powershell_secret_pattern_trigger.md`（対比：コマンドのシークレットで trigger）
