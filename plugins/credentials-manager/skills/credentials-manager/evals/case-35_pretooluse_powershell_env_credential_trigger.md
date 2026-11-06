# Case 35: PreToolUse hook — PowerShell + `$env:GITHUB_TOKEN = ...` → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"$env:GITHUB_TOKEN = \"<dummy>\""}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- `$env:NAME = ...` 形式の代入で、変数名 `GITHUB_TOKEN` が認証情報キーワード `TOKEN` を含む
- `REASON` = `PowerShell で認証情報らしい環境変数を設定`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `PowerShell で認証情報らしい環境変数を設定` を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

ルールテンプレートの 1.3 が例示する `$env:FOO_TOKEN = ...` の検出ケース。次の書き方も同じ分岐で trigger する
（変数名の大文字小文字は区別しない）。

| 書き方 | 例 |
|-------|---|
| 代入・追記 | `$env:github_token="..."` / `$env:GITHUB_TOKEN += "..."` / `${env:API_KEY} = '...'` |
| .NET API | `[Environment]::SetEnvironmentVariable('OPENAI_API_KEY', '...', 'User')` |
| プロバイダ | `Set-Item -Path Env:DB_PASSWORD -Value '...'` / `Set-Item Env:/DB_PASSWORD '...'` / `Set-Content Env:SERVICE_TOKEN '...'` / `New-Item -Path Env: -Name API_KEY -Value '...'` / 別名の `si Env:API_KEY '...'` / `ni Env:API_KEY -Value '...'` |
| 永続化 | `setx GITHUB_TOKEN "..."` / `setx /M GITHUB_TOKEN "..."` |

キーワードは Bash の `export` / `set` と同じ（`TOKEN` / `KEY` / `SECRET` / `PASSWORD` / `PASSWD` / `API` / `AUTH` / `CREDENTIAL` / `SESSION` / `BEARER` / `PRIVATE`）。
設定は 1 行で完結するため、照合は改行をまたがない。
値の参照（`$env:GITHUB_TOKEN` を読むだけ）は対象外（`case-40` で確認）。
`-Name` を `-Path Env:` より前に書く `New-Item` と、レジストリ（`HKCU:\Environment`）経由の設定は検出しない（既知の制約）。

## 関連ケース

- `case-30_pretooluse_bash_env_credential_trigger.md`（同じ検出で Bash の `export` 側）
- `case-38_pretooluse_powershell_env_noncredential_noop.md`（対比：無関係な環境変数で no-op）
- `case-39_pretooluse_bash_pwsh_env_credential_trigger.md`（Bash から `pwsh -c` で設定する経路）
