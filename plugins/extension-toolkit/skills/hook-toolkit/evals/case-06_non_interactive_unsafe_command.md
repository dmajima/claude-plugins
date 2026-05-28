# Case 06: 非対話モード + 危険な command 入力 → fail-closed エラー終了

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PreToolUse フックで Bash 実行をログ（自動）" |
| 引数 | `--non-interactive --plugin dev-toolkit --event PreToolUse --matcher Bash --command "C:\Users\me\scripts\log.bat" --timeout 5` |
| フラグ | `--non-interactive` |
| 既存状態 | フック未存在 |

## 期待動作

### Phase 1: モード判定 + 危険パターン検出

`--non-interactive` 検出 → 非対話モード（対話確認なし）。
`--command` の値を検査:

| パターン | 該当 | リスク |
|---------|------|------|
| ローカル絶対パス（`C:\Users\me\scripts\log.bat`）| **該当** | パスポータビリティ NG |
| `$(...)` / `` `...` ``（コマンド置換）| 非該当 | - |
| `eval ...` / `bash -c ...` | 非該当 | - |

ローカル絶対パスを検出 → **fail-closed**。

### Phase 2: エラー終了（対話なし）

非対話モードでは `AskUserQuestion` による修正提案フローが成立しないため、即時エラー終了:

```text
[hook-toolkit] Error: Unsafe command pattern detected (non-interactive mode).

Detected: ローカル絶対パスのハードコード（C:\Users\me\scripts\log.bat）

Non-interactive mode does not support interactive remediation. Either:
1. Use ${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log-tool-use.sh (recommended for plugin-bundled scripts, PowerShell unified per shell-preference.md)
2. Use ${HOME}/.claude/scripts/log-tool-use.sh (assumes the path exists in user environment)
3. Run in interactive mode for AskUserQuestion-based remediation flow

References: ../../references/path-portability.md
```

`exit 1` で終了。**`hooks.json` は生成しない**（破損した設定ファイルを残さない）。

### Phase 3: 引き渡し（処理停止）

| 項目 | 動作 |
|-----|------|
| `hooks.json` 生成 | なし |
| 既存ファイル | 無変更 |
| 終了コード | 1 |
| ユーザ対話 | 発生しない |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | なし |
| 標準エラー出力 | 危険パターン警告 + 解決方法 3 案内 + 参照規約 |
| 終了状態 | 失敗（exit 1）|

## 分岐の根拠

`--non-interactive` + 危険パターン検出（パスポータビリティ NG / コマンド置換 / eval 等）→ fail-closed。
case-05（対話モード + 危険コマンド）の AskUserQuestion 修正提案フローと対称な同値分割の対称ペア。
hook の command フィールドは利用者環境で実行されるため、危険パターン混入のリスクは特に高く、非対話モードでも検出を緩めない。

## 関連ケース

- `case-05_unsafe_command_warning.md`（対話モード + 危険コマンド検出、修正提案）
- `case-04_non_interactive.md`（非対話モード、安全な command の正常生成）
