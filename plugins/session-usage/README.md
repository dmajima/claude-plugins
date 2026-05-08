# session-usage

カレントセッション（または指定セッション）のトークン消費量を JSONL から直接集計し、
**`/doctor` 風の対話 TUI** でフルスクリーン表示・クリップボードコピー可能にするプラグイン。

外部プラグイン（ccusage 等）には一切依存せず、PowerShell 標準機能のみで動作する。

## 機能

- **正確な集計**: `~/.claude/projects/<projectKey>/<sessionId>.jsonl` を直接パース
- **整形表示**: `/doctor` 風の罫線レイアウト、k tokens 単位、利用比率付き
- **対話 TUI**: 新規ウィンドウで起動、キー入力で操作
  - `[c]` クリップボードコピー
  - `[r]` 再集計（リアルタイム更新）
  - `[q]` / ESC 終了
- **セッション識別**: rename 済セッション名（custom-title）/ AI 自動生成タイトル（ai-title）を表示
- **モデル別内訳**: 複数モデル使用時のみ自動表示
- **Server Tool 使用回数**: web_search / web_fetch を 0 でないときだけ表示

## インストール

```bash
claude plugin install session-usage@dmajima-claude-plugins
```

## 利用方法

### コマンド経由

```
/session-usage                    # カレントセッション
/session-usage <UUID>             # 指定セッション
```

### 自然言語起動

「セッションのトークン使用量を見せて」「今回の消費量教えて」等で自動的に
`session-usage` スキルがトリガーされる。

## 動作環境

- Windows
- PowerShell 7+ （`pwsh` が PATH 上にあること）
- Windows Terminal（推奨。無くても conhost で動作）

## 表示例

```
╔════════════════════════════════════════════════════════╗
║  Claude Code  Session Usage                            ║
╚════════════════════════════════════════════════════════╝

  Session  : セッション使用量合計を表示するコマンド作成 (auto)
  ID       : 409dc664-c57f-4263-bf55-fb527475a536
  Period   : 2026-05-08 14:22 - 15:46  (1.4 h)
  Requests : 147

  ┌── Token Consumption ───────────────────────────────────┐
  │  Input               :        0.3k tokens (  0.0%)  │
  │  Cache Creation      :      612.4k tokens (  2.7%)  │
  │  Cache Read          :   21,602.8k tokens ( 96.3%)  │
  │  Output              :      220.5k tokens (  1.0%)  │
  │                        ───────────────────────────   │
  │  Total               :   22,436.0k tokens             │
  └────────────────────────────────────────────────────────┘

────────────────────────────────────────────────────────
  [c] Copy clipboard   [r] Refresh   [q] Quit (or ESC)
```

## アーキテクチャ

```
plugins/session-usage/
├── .claude-plugin/plugin.json
├── LICENSE                              # MIT
├── README.md                            # 本ファイル
├── commands/
│   └── session-usage.md                 # スラッシュコマンド（スキル呼び出しのみ）
└── skills/
    └── session-usage/
        ├── SKILL.md                     # スキル定義
        ├── scripts/
        │   ├── aggregate/
        │   │   └── aggregate.ps1        # JSONL 集計+整形（純粋関数）
        │   └── tui/
        │       ├── tui.ps1              # 対話 TUI 本体（ReadKey ループ）
        │       └── launch.ps1           # 新規ウィンドウで TUI を起動
        └── references/
            ├── procedures.md            # 実行手順詳細
            └── tui-spec.md              # TUI 仕様（画面構成・キーバインド）
```

### なぜ別ウィンドウなのか

Claude Code のカスタムコマンドは Bash ツール経由で実行される。Bash ツールは
`stdin` が閉じた非対話モードで動くため、`[System.Console]::ReadKey()` による
キー入力受付が成立しない。

そのため `launch.ps1` は新規 PowerShell ウィンドウ（Windows Terminal 優先）を
開き、そこで `tui.ps1` を実行する。これにより `/doctor` 同等のフルスクリーン
対話体験を Claude Code から起動できる。

## 集計仕様

| 項目 | ソース |
|-----|--------|
| Input | `message.usage.input_tokens` |
| Cache Creation | `message.usage.cache_creation_input_tokens` |
| Cache Read | `message.usage.cache_read_input_tokens` |
| Output | `message.usage.output_tokens` |
| Web Search Requests | `message.usage.server_tool_use.web_search_requests` |
| Web Fetch Requests | `message.usage.server_tool_use.web_fetch_requests` |
| Session Name | 最後の `custom-title.customTitle`、無ければ最後の `ai-title.aiTitle` |
| Period | 最初／最後の `assistant` レコードの `timestamp` |
| Requests | `assistant` レコード件数 |

集計は **`type=assistant` レコードのみ** を対象とする。

## ライセンス

MIT License.

## 著者

dmajima
