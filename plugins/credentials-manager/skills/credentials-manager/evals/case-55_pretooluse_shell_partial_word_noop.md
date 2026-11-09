# Case 55: PreToolUse hook — シェルのコマンドで認証情報系ファイルの名前の一部だけが一致 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"ls plugins/credentials-manager/skills"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 手掛かりの語（`credential`）を含むため、トークンごとにファイル系ツールと同じ規則で判定する
- `plugins/credentials-manager/skills` は、ファイル名の完全一致・拡張子・特殊ディレクトリのいずれにも該当しない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

手掛かりの語は、トークンに分けて判定するかを決めるための絞り込みであり、それだけでは通知しない。
語の一部の一致で通知すると、`credentials-manager` のようなパスを含むコマンドのたびに誤って通知されるため、トークンをファイル名として判定する。

## 関連ケース

- `case-46_pretooluse_shell_credential_file_trigger.md`（対比：trigger するケース）
- `case-49_pretooluse_grep_glob_noop.md`（同じ境界を Grep / Glob で判定するケース）
