# フックイベント詳細

Claude Code のフックイベント別の意味と使い方。

## イベント一覧

| イベント | タイミング | matcher 必要 | 主な用途 |
|---------|----------|------------|---------|
| `PreToolUse` | ツール呼び出し前 | はい（ツール名） | ログ・検証・ブロック |
| `PostToolUse` | ツール呼び出し後 | はい（ツール名） | 後処理・通知 |
| `UserPromptSubmit` | ユーザプロンプト送信時 | 不要 | 入力前処理 |
| `Stop` | 応答完了時 | 不要 | 完了通知・ビープ音 |
| `SessionStart` | セッション開始時 | 不要 | 初期化・環境変数 |
| `SessionEnd` | セッション終了時 | 不要 | クリーンアップ |
| `SubagentStop` | サブエージェント完了時 | 不要 | サブ完了処理 |
| `Notification` | 通知発生時 | 不要 | 通知のカスタマイズ |
| `PreCompact` | コンテキスト圧縮前 | 不要 | 圧縮前のメモリ保存 |

## matcher 設計

### PreToolUse / PostToolUse

| matcher | マッチ |
|--------|------|
| `Bash` | Bash ツールのみ |
| `Edit\|Write` | Edit または Write |
| `.*` | 全ツール（パフォーマンス注意） |
| `mcp__.*` | MCP 系ツール全部 |

### その他のイベント

通常 matcher 不要。必要時は該当文字列の正規表現を指定。

## command 設計

### 構造

```json
{
  "type": "command",
  "command": "<実行コマンド>",
  "timeout": 30
}
```

| フィールド | 内容 |
|----------|------|
| `type` | `command` 固定 |
| `command` | シェルコマンド本体 |
| `timeout` | 秒単位、デフォルト 60 |

### パスポータビリティ

| 用途 | 推奨記法 |
|-----|---------|
| プラグイン同梱スクリプト呼び出し | `${CLAUDE_PLUGIN_ROOT}/scripts/{name}` |
| プラグインのデータ領域 | `${CLAUDE_PLUGIN_DATA}/...` |
| ホームディレクトリ | `~/.claude/...` |

ローカル絶対パスのハードコード禁止。詳細は [`../../../references/path-portability.md`](../../../references/path-portability.md) を参照。

### タイムアウト設計

| 処理の重さ | 推奨 timeout |
|----------|------------|
| ログ書き込み・通知 | 5〜10 秒 |
| 検証スクリプト | 30 秒 |
| ビルド・テスト | 60〜180 秒 |

`PreToolUse` は短めにする（ユーザ体験を阻害しない）。

### 終了コードの意味

| 終了コード | 意味 |
|----------|------|
| `0` | 成功（処理続行） |
| `2` | ブロック（ツール実行を阻止、stderr のメッセージを Claude に伝達） |
| その他 | 失敗（処理続行、stderr を Claude に伝達） |

## サンプル

### PreToolUse: Bash 実行前のコマンドログ

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

### Stop: 完了時にビープ音（Windows）

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -c \"[console]::beep(800,200)\"",
            "timeout": 3
          }
        ]
      }
    ]
  }
}
```

### SessionStart: 初期メッセージ表示

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Session started: $(date)'",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

### PreToolUse: 危険コマンドのブロック

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/block_dangerous.js",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

`block_dangerous.js` で危険コマンドを検出した場合、終了コード 2 を返してブロックする。

## settings.json への追加時の注意

`settings.json` の既存エントリを破壊しないようマージ書き戻す:

```python
# Python サンプル（既存 settings.json への追加）
import json

with open(settings_path, 'r', encoding='utf-8') as f:
    settings = json.load(f)

if 'hooks' not in settings:
    settings['hooks'] = {}
if 'PreToolUse' not in settings['hooks']:
    settings['hooks']['PreToolUse'] = []

settings['hooks']['PreToolUse'].append({
    "matcher": "Bash",
    "hooks": [{"type": "command", "command": "...", "timeout": 5}]
})

with open(settings_path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
```

## 動作確認

| ステップ | 内容 |
|---------|------|
| 1 | Claude Code 再起動 |
| 2 | フックが反応する操作を実行 |
| 3 | 期待される副作用（ログ・通知等）を確認 |
| 4 | エラー時は標準エラー出力を確認 |
