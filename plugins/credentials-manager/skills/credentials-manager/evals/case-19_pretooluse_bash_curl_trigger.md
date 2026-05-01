# Case 19: PreToolUse hook — Bash + curl → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer X\" https://api.example.com/data"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` を抽出 → `Bash`
- `Bash` 分岐に入り、`tool_input.command` を抽出

### Phase 2: コマンド解析

- 単語境界つき正規表現で `curl` を検出 → 外部通信コマンド該当
- `set_reason "Bash で外部通信または認証付きクライアントを実行"` に到達

### Phase 3: Claude へ通知

- `additionalContext` で credentials-manager 最優先起動を要求

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（外部通信検出 reason 含む） |
| 終了コード | 0 |

## 分岐の根拠

`Bash` 内の外部通信コマンド検出分岐。`gh` / `wget` / `ssh` / `aws` 等も同分岐。

## 関連ケース

- `case-20_pretooluse_bash_local_noop.md`（同 Bash でも no-op となる対比）
- `case-27_pretooluse_bash_iac_trigger.md`（IaC CLI 系の trigger）
