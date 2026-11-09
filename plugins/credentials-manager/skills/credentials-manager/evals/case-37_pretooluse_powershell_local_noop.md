# Case 37: PreToolUse hook — PowerShell + 必須プリフィクス付きのローカルコマンド → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"& chcp.com 65001 \| Out-Null; [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; $OutputEncoding = [System.Text.Encoding]::UTF8; Get-ChildItem -Recurse -Filter *.md"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 文字コード設定の必須プリフィクス（`chcp.com` / `[Console]::...Encoding = ...` / `$OutputEncoding = ...`）と `Get-ChildItem` は、
  外部通信 CLI・PowerShell 系の通信コマンドのいずれにも一致しない
- `$OutputEncoding = ...` は `$env:` への代入ではないため、環境変数の設定にも一致しない
- シークレットパターンにも一致せず、`REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

PowerShell 側の過検出抑制の重要分岐。PowerShell ツールは必須プリフィクスを付けて呼ばれることが多く、
プリフィクスで誤発火すると全呼び出しに通知が付き、context の消費が増大する。
`Get-Process` / `Get-Command bash -All` / `Copy-Item .\docs\ssh-notes.md .\out\`（パス中の `ssh` は CLI の `ssh` ではない）も同様に no-op。
なお `~/.ssh` などの認証情報のディレクトリを指すコマンド（`Test-Path "$HOME\.ssh"`）は、認証情報系ファイルの操作として通知される（`case-46`）。

一方、パスの末尾の要素や引用符の中の語が CLI 名と一致する場合（`Set-Location .\terraform` / `Write-Output "HTTP status: 200"`）は
通知される（既知の誤検出。PowerShell ではパス付き・引用符付きの起動を検出するため）。

## 関連ケース

- `case-20_pretooluse_bash_local_noop.md`（同じ no-op カテゴリで Bash 側）
- `case-32_pretooluse_powershell_invoke_restmethod_trigger.md`（対比：trigger するケース）
- `case-40_pretooluse_powershell_env_reference_noop.md`（環境変数の参照で no-op）
- `case-41_pretooluse_powershell_cli_name_in_path_noop.md`（CLI 名を含むパスで no-op）
