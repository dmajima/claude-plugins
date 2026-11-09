# Case 32: PreToolUse hook — PowerShell + Invoke-RestMethod → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"Invoke-RestMethod -Uri https://api.example.com/v1/users"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: フックの起動とツール種別判定

- `hooks.json` の PreToolUse の matcher が `PowerShell` を含むため、フックが起動する
- `tool_name` → `PowerShell` で `Bash|PowerShell` 分岐に入り、`tool_input.command` を抽出

### Phase 2: コマンド解析

- PowerShell 系の外部通信パターン（大文字小文字を区別しない）が `Invoke-RestMethod` に一致する
- `REASON` = `PowerShell で外部通信コマンド（Invoke-WebRequest 等）を実行`

### Phase 3: Claude へ通知

- `additionalContext` で **`credentials-reader`** の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `PowerShell で外部通信コマンド（Invoke-WebRequest 等）を実行` と credentials-reader の起動指示を含む JSON |
| 終了コード | 0 |
| Claude のコンテキスト | credentials-reader の起動指示が追加される |

## 分岐の根拠

PowerShell ツールの基本の検出ケース。PowerShell ツールを検査するには、`hooks.json` の matcher と
スクリプトの `case` 分岐の両方に `PowerShell` が含まれている必要がある（片方だけでは検査されない）。
`Invoke-WebRequest` / `Start-BitsTransfer` / `Net.WebClient` / `Net.Http.HttpClient` / `[Net.WebRequest]` も同じ分岐で検出する。

## 関連ケース

- `case-19_pretooluse_bash_curl_trigger.md`（同じ外部通信の検出で Bash 側）
- `case-33_pretooluse_powershell_irm_lowercase_trigger.md`（別名・小文字表記）
- `case-37_pretooluse_powershell_local_noop.md`（対比：no-op のケース）
