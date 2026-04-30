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

### セキュリティ設計（command の安全な書き方）

フック `command` フィールドはシェルで評価されるため、**コマンドインジェクションの混入リスク** がある。以下を遵守する。

| ルール | 理由 |
|-------|------|
| 動的データ（ユーザ入力・環境依存値）を `command` に文字列補間で組み立てない | 文字列補間はインジェクションの主要経路 |
| 動的データが必要なら **外部スクリプトに委譲** し、引数として安全に受け渡す（`script.sh "$1"` でクォート） | スクリプト内で適切にクォートする責務を分離できる |
| `command` 内で `$(...)` や `` `...` ``（コマンド置換）を多用しない。固定文字列で済ませる | 置換結果が予期せぬ値の場合に任意コード実行に発展しうる |
| `eval` の使用を避ける | 文字列を実行する設計上、サニタイズが極めて困難 |
| 入出力データを処理する場合は jq 等の構造化ツールを使い、`grep` / `cut` での粗い切り出しを避ける | 改行や特殊文字を含む値で破綻しやすい |

#### 良い例

```json
{
  "type": "command",
  "command": "${CLAUDE_PLUGIN_ROOT}/scripts/log-tool-use.sh",
  "timeout": 5
}
```

スクリプト側で `set -euo pipefail` と適切なクォート（`"$1"` 等）を行う。

#### 悪い例（避けるべき）

```json
{
  "type": "command",
  "command": "echo \"$(curl https://example.invalid/$USER_INPUT)\""
}
```

外部入力を直接文字列補間しているため、`$USER_INPUT` に `` `cmd` `` や `;` を含む値が来た場合に任意コード実行となる。

これらは `hook-security-team` のレビュー観点としても扱われる（[`../../../references/teams/hook-security-team.md`](../../../references/teams/hook-security-team.md) 参照）。

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

### SessionStart: 初期化スクリプトの呼び出し

動的データ（タイムスタンプ等）を扱う場合は、`command` フィールド内で `$(...)` を使わず、外部スクリプトに委譲する（コマンドインジェクション対策、本ファイル「セキュリティ設計」節参照）。

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/log-session-start.sh",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

`log-session-start.sh` 側で `set -euo pipefail` のもと、必要な処理（タイムスタンプ取得・ログ書き込み等）を実装する。`command` 内で直接 `$(date)` を実行する形は、利用者が動的入力を含むよう書き換える誘惑を招くため非推奨。

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
