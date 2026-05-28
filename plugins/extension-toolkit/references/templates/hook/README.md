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
- `shell` フィールドで実行シェルを **明示的に指定** する（後述「shell 指定（MANDATORY）」参照）

## shell 指定（MANDATORY）

各 hook エントリには `"shell"` フィールドを **必ず** 明示する。`type: "command"` と同じ階層に配置する。

| 値 | 用途 |
|---|---|
| `"bash"` | Git Bash / bash（**本マーケットプレイス標準**、通常運用） |
| `"powershell"` | Windows PowerShell / pwsh（PowerShell フォールバック適用時、Git Bash 不調時の保険） |

### 指定する理由

- `command` が `bash ...` 形式でも、OS デフォルトシェルが PowerShell の場合に `bash.exe` の引数解釈や PATH 解決で不整合が起きうる
- `"shell": "bash"` を明示することで、Claude Code が Bash ホストで command を起動する意図を一義的に伝達できる
- `shell` フィールド未指定（OS デフォルト依存）は本マーケットプレイス基準では **不可**
- 既存 Claude Code バージョンが `shell` フィールドを認識しない場合でも無視されるだけで、後方互換性は維持される（[`shell-preference.md`](https://github.com/dmajima/claude-plugins) と整合）

> **テンプレートファイル注記**: 本 README はテンプレート格納場所（`references/templates/hook/`）にあるため、相対リンクではなく `${CLAUDE_PLUGIN_ROOT}` 起点の絶対パス記法で参照を記述する。テンプレートが配備された後はそれぞれの場所からの相対パスで解決される。

## 終了コードと意味

| 終了コード | 意味 |
|----------|------|
| `0` | 成功（処理続行） |
| `2` | ブロック（ツール実行を阻止、stderr のメッセージを Claude に伝達） |
| その他 | 失敗（処理続行、stderr を Claude に伝達） |

## サンプル

### PreToolUse: コマンド実行前のログ記録

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log_command.sh\"",
            "shell": "bash",
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
            "command": "printf '\\a'",
            "shell": "bash",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```
