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
  "shell": "powershell",
  "timeout": 30
}
```

| フィールド | 必須 | 内容 |
|----------|-----|------|
| `type` | はい | `command` 固定 |
| `command` | はい | シェルコマンド本体 |
| `shell` | **はい** | 実行シェル名（`"powershell"` または `"bash"`）。本マーケットプレイスでは **必ず `"powershell"` を明示** する。詳細は本ファイル「shell 指定（MANDATORY）」を参照 |
| `timeout` | いいえ | 秒単位、デフォルト 60 |

### shell 指定（MANDATORY）

各 hook エントリで実行シェルを明示する。`type: "command"` と同階層に `"shell"` フィールドを置く。

| 値 | 用途 | 推奨度 |
|---|---|------|
| `"bash"` | Git Bash / bash で実行 | **本マーケットプレイスのデフォルト** |
| `"powershell"` | Windows PowerShell / pwsh で実行 |  |
| `"bash"` | POSIX bash で実行 | macOS / Linux 限定（本マーケットプレイスでは未使用） |

#### 必須化の根拠

- `command` を `bash "..."` 形式で記述しても、Claude Code が起動する **ホスト側シェル** が PowerShell の場合に、引数解釈や PATH 解決でエッジケースが発生しうる（フォールバック時は `pwsh -NoProfile -File "..."`）
- `~/.claude/rules/tools/shell-preference.md`（`Bash` ツール標準・`PowerShell` ツールはフォールバック適用時）の方針と整合させるため、フック実行も PowerShell ホストで起動する意図を一義的に伝える必要がある
- `"shell": "powershell"` を明示することで、Claude Code が PowerShell ホストでコマンドを起動する意図をプラグイン側で表明できる
- `shell` フィールド未対応の古い Claude Code では無視されるため、後方互換性は維持される

#### NG / OK の対比

NG（shell 未指定。OS デフォルトに依存し Git Bash で起動される可能性がある）:

```json
{
  "type": "command",
  "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/foo.sh\"",
  "timeout": 10
}
```

OK（shell 明示）:

```json
{
  "type": "command",
  "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/foo.sh\"",
  "shell": "powershell",
  "timeout": 10
}
```

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
  "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log-tool-use.sh\"",
  "shell": "powershell",
  "timeout": 5
}
```

スクリプト側で `Set-StrictMode -Version Latest` と `$ErrorActionPreference = 'Stop'` を設定し、stdin から JSON を `ConvertFrom-Json` で読み取って構造化処理する。

#### 悪い例（避けるべき）

```json
{
  "type": "command",
  "command": "curl -s https://example.invalid/$user",
  "shell": "powershell"
}
```

外部入力を直接文字列補間しているため、`$input.user` に `;` や `` ` `` を含む値が来た場合に任意コード実行となる。

これらは `hook-security-team` のレビュー観点としても扱われる（[`../../../references/teams/hook-security-team.md`](../../../references/teams/hook-security-team.md) 参照）。

## サンプル

### PreToolUse: PowerShell 実行前のコマンドログ

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
            "shell": "powershell",
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
            "command": "printf \"\a\"",
            "shell": "powershell",
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
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log-session-start.sh\"",
            "shell": "powershell",
            "timeout": 2
          }
        ]
      }
    ]
  }
}
```

`log-session-start.sh` 側で `Set-StrictMode -Version Latest` と `$ErrorActionPreference = 'Stop'` のもと、必要な処理（タイムスタンプ取得・ログ書き込み等）を実装する。`command` 内で直接 `Get-Date` を実行する形は、利用者が動的入力を含むよう書き換える誘惑を招くため非推奨。

### PreToolUse: 危険コマンドのブロック

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/block_dangerous.sh\"",
            "shell": "powershell",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

`block_dangerous.sh` で危険コマンドを検出した場合、終了コード 2 を返してブロックする。

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
    "matcher": "PowerShell",
    "hooks": [{
        "type": "command",
        "command": "bash \"${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/foo.sh\"",
        "shell": "powershell",
        "timeout": 5,
    }],
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
