# Case 34: PreToolUse hook — PowerShell + curl.exe / パス付きの gh.exe → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"PowerShell","tool_input":{"command":"curl.exe https://api.example.com/v1/users"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"PowerShell","tool_input":{"command":"& 'C:\\Program Files\\GitHub CLI\\gh.exe' api user"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 外部通信 / IaC / シークレット管理 CLI の名前に、拡張子 `.exe` / `.cmd` が付いていても一致する
- PowerShell では CLI 名を大文字小文字を区別せずに照合し、直前の `\` `/`（パス付き）・引用符・`{` `=`、直後の引用符も許容する
  （`$r=curl.exe ...` / `$u=gh api user` / `{gh api user}` / `& 'gh' api user` も同じ）
- いずれも `REASON` = `PowerShell で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `PowerShell で外部通信 / 認証付きクライアント / IaC / シークレット管理 CLI を実行` を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

Windows では `curl` が `Invoke-WebRequest` の別名と衝突するため `curl.exe` と書くことが多く、CLI はパス付き・引用符付きでも起動される。
そのため、拡張子・パス区切り・引用符を許して照合する。
一方、`gh-pages` や `.\docs\op\` のように CLI 名の後に `-` や `\` が続く場合は一致しない（`case-41` で確認）。
Bash では大文字小文字を区別し、パス付きの起動（`/usr/bin/curl`）は検出しない（`.exe` / `.cmd` 付きは Bash でも検出する）。

## 関連ケース

- `case-32_pretooluse_powershell_invoke_restmethod_trigger.md`（PowerShell 系の通信コマンド）
- `case-41_pretooluse_powershell_cli_name_in_path_noop.md`（対比：CLI 名を含むパスで no-op）
