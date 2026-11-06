# Case 41: PreToolUse hook — PowerShell + CLI 名を含むパス → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"Set-Location C:\\repos\\gh-pages; git status"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- `\gh-pages` は CLI 名 `gh` の直前にパス区切りがあるが、直後に `-` が続くため一致しない
  （CLI 名の直後に許すのは空白・引用符・行末のみ）
- `git` は外部通信 CLI の一覧に含まれない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

パス付きの起動（`C:\...\gh.exe`）を検出するためにパス区切りを境界に含めたことに対する、過検出抑制の境界ケース。
`Copy-Item .\docs\op\readme.md .\out\`（`op` の直後に `\`）も同様に no-op。
パスの末尾の要素が CLI 名と一致する場合（`Set-Location .\terraform`）は通知される（既知の誤検出）。

## 関連ケース

- `case-34_pretooluse_powershell_cli_exe_path_trigger.md`（対比：パス付きの起動で trigger するケース）
- `case-37_pretooluse_powershell_local_noop.md`（ローカルコマンドで no-op）
