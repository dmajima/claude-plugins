# Hook テンプレート

Claude Code フックの設定テンプレート。`hooks/hooks.json` 1 ファイルで完結する。

## 利用可能なイベント

| イベント | タイミング |
|---------|----------|
| `PreToolUse` | ツール呼び出し前 |
| `PostToolUse` | ツール呼び出し後 |
| `UserPromptSubmit` | ユーザプロンプト送信時 |
| `Stop` | 応答完了時 |
| `SessionStart` | セッション開始時 |
| `SessionEnd` | セッション終了時 |
| `SubagentStop` | サブエージェント完了時 |
| `Notification` | 通知時 |
| `PreCompact` | コンテキスト圧縮前 |

## matcher の書き方

| イベント | matcher の意味 |
|---------|--------------|
| `PreToolUse` / `PostToolUse` | ツール名の正規表現（例: `Bash`, `Edit\|Write`） |
| その他 | 通常は不要（あれば該当文字列の正規表現） |

## command の制約

- `${CLAUDE_PLUGIN_ROOT}` を活用してプラグイン内スクリプトを呼び出す
- ローカル絶対パスのハードコード禁止（パスポータビリティ規約: `${CLAUDE_PLUGIN_ROOT}/references/path-portability.md`）
- timeout は秒単位、デフォルト 60 秒

> **テンプレートファイル注記**: 本 README はテンプレート格納場所（`references/templates/hook/`）にあるため、相対リンクではなく `${CLAUDE_PLUGIN_ROOT}` 起点の絶対パス記法で参照を記述する。テンプレートが配備された後はそれぞれの場所からの相対パスで解決される。

## 終了コードと意味

| 終了コード | 意味 |
|----------|------|
| `0` | 成功（処理続行） |
| `2` | ブロック（ツール実行を阻止、stderr のメッセージを Claude に伝達） |
| その他 | 失敗（処理続行、stderr を Claude に伝達） |

## サンプル

### Bash 実行前にコマンドをログ記録

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/log_command.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### Stop 時にビープ音

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -c \"[console]::beep(800,200)\""
          }
        ]
      }
    ]
  }
}
```
