# Case 39: PreToolUse hook — Bash + `pwsh -c "$env:GITHUB_TOKEN = ..."` → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Bash","tool_input":{"command":"pwsh -c \"$env:GITHUB_TOKEN = '<dummy>'\""}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Bash`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- Bash の `export` / `set` パターンには一致しない
- PowerShell / Windows の環境変数設定パターンは Bash のコマンドにも適用され、`$env:GITHUB_TOKEN = ...` に一致する
- `REASON` = `Bash で認証情報らしい環境変数を設定`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `Bash で認証情報らしい環境変数を設定` を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

Bash ツールから `pwsh -c` / `powershell -c` で PowerShell を起動する経路の検出ケース。
PowerShell / Windows の環境変数設定のパターンは Bash のコマンドにも適用する。同様に `powershell -c "irm ..."` は
PowerShell 系の通信コマンドとして、`curl.exe ...` は外部通信 CLI として、Bash ツールでも検出する。

## 関連ケース

- `case-35_pretooluse_powershell_env_credential_trigger.md`（同じ設定を PowerShell ツールで行うケース）
- `case-30_pretooluse_bash_env_credential_trigger.md`（Bash の `export` で設定するケース）
