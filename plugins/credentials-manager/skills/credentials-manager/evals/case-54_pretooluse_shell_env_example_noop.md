# Case 54: PreToolUse hook — シェルで .env の雛形（.env.example 等）を操作 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"cat .env.example"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 手掛かりの語（`.env`）を含むため、トークンごとにファイル系ツールと同じ規則で判定する
- `.env.example` は `.env.<name>` の形だが、除外リスト（`.example` / `.sample` / `.template` / `.dist` / `.test` / `.spec`）に該当する
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

`.env.example` 等は値を含まない雛形としてリポジトリに置かれることが多く、読み書きのたびに通知すると誤検出が増える。
除外リストは `Read` 等のファイル系ツールと共通（`case-22`）。`cp .env.example .env` のように実際の `.env` を指すトークンがあれば通知する（`case-46`）。

## 関連ケース

- `case-22_pretooluse_read_env_example_noop.md`（同じ除外リストを Read ツールで判定するケース）
- `case-46_pretooluse_shell_credential_file_trigger.md`（対比：trigger するケース）
