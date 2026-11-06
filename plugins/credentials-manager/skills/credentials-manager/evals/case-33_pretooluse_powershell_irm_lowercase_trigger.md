# Case 33: PreToolUse hook — PowerShell + 行頭の irm / 小文字表記 → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"PowerShell","tool_input":{"command":"irm https://api.example.com/v1/users"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"PowerShell","tool_input":{"command":"invoke-restmethod https://api.example.com/v1/users"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- 例 1: 別名 `irm` / `iwr` は、行頭・空白・`;` `|` `&` `(` `{` `=`・引用符の直後にあり、空白・`(`・引用符・行末が続く場合に一致する
  （`$r=irm ...` / `{irm ...}` / `irm('...')` / `& 'irm' ...` / `powershell -c "irm ..."` も同じ）
- 例 2: PowerShell 系のコマンド名は大文字小文字を区別せずに照合する
- いずれも `REASON` = `PowerShell で外部通信コマンド（Invoke-WebRequest 等）を実行`

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動を指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `PowerShell で外部通信コマンド（Invoke-WebRequest 等）を実行` を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

PowerShell はコマンド名の大文字小文字を区別せず、別名はコマンドを置ける位置（行頭・代入の右辺・スクリプトブロックの中等）
ならどこでも使える。そのため、大文字小文字を区別せずに照合し、別名はこれらの位置にあるものを検出する。

## 関連ケース

- `case-32_pretooluse_powershell_invoke_restmethod_trigger.md`（正規の表記）
- `case-34_pretooluse_powershell_cli_exe_path_trigger.md`（CLI の表記揺れ）
