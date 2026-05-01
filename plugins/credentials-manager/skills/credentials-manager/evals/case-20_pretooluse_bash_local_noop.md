# Case 20: PreToolUse hook — Bash + ローカルコマンド → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"ls -la /tmp && git status"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- `ls` / `git status` は外部通信コマンドリストに含まれない
- 認証情報環境変数 export パターンにもマッチしない
- シークレットパターンにもマッチしない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

過検出抑制の重要分岐。ローカル完結コマンドで誤発火しないことの根拠ケース。
リグレッションでこのケースが trigger に変わると、無関係な Bash 操作にも通知が走り Claude の context 消費が増大する。

## 関連ケース

- `case-19_pretooluse_bash_curl_trigger.md`（対比：trigger するケース）
- `case-31_pretooluse_read_readme_noop.md`（同じ no-op カテゴリで Read 側）
