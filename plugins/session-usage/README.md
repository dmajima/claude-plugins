# session-usage

カレントセッション（または指定セッション）のトークン消費量を JSONL から直接集計し、
**Claude UI のコンテキスト内** で `/doctor` 風レイアウトで表示するプラグイン。
表示後は `AskUserQuestion` による対話ループで「クリップボードへコピー / 再集計 / 終了」
を選択できる（クリップボードコピーは選択時のみ実行され、自動コピーは行わない）。

外部プラグイン（ccusage 等）には一切依存せず、Bash + Python 標準機能のみで動作する。

## 機能

- **正確な集計**: `~/.claude/projects/<projectKey>/<sessionId>.jsonl` を直接パース
- **整形表示**: `/doctor` 風の罫線レイアウト、k tokens 単位、利用比率付き
- **対話ループ**: `AskUserQuestion` による 3 択（クリップボードコピー / 再集計 / 終了）
- **折りたたまれない表示**: 集計結果は `AskUserQuestion` の `preview` フィールドに埋め込まれ、Claude UI の左右分割レイアウトで右ペインに monospace box として全文表示される
- **明示的コピー**: 自動コピーは行わず、ユーザが「クリップボードへコピー」を選んだときだけ Set-Clipboard 実行
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

- Python 3.8+ (`python` / `python3` / `py` のいずれかが PATH 上にあること、通常運用)
- 任意プラットフォーム (Windows / macOS / Linux)

## 表示例

```
╔════════════════════════════════════════════════════════╗
║  Claude Code  Session Usage                            ║
╚════════════════════════════════════════════════════════╝

  Session  : セッション使用量合計を表示するコマンド作成 (auto)
  ID       : 409dc664-c57f-4263-bf55-fb527475a536
  Period   : 2026-05-08 14:22 - 16:05  (1.7 h)
  Requests : 237

  ┌── Token Consumption ───────────────────────────────────┐
  │  Input               :        0.5k tokens (  0.0%)  │
  │  Cache Creation      :      700.8k tokens (  1.5%)  │
  │  Cache Read          :   44,796.2k tokens ( 97.8%)  │
  │  Output              :      314.9k tokens (  0.7%)  │
  │                        ───────────────────────────────   │
  │  Total               :   45,812.4k tokens             │
  └────────────────────────────────────────────────────────┘

→ AskUserQuestion: [クリップボードへコピー] [再集計] [終了]
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
        ├── README.md                    # 人間向けリファレンス
        ├── scripts/
        │   └── aggregate/
        │       └── aggregate.sh        # JSONL 集計+整形+コピー（-Stdout / -Copy）
        └── references/
            └── procedures.md            # 実行手順詳細
```

### Claude UI 内対話の理由

Claude Code のカスタムコマンドは Bash ツール経由で実行される。Bash ツールは
`stdin` が閉じた非対話モードで動くため、`[System.Console]::ReadKey` による
キー入力受付が成立しない。

そのため、`c` キー / `q` キー等の直接的なキーバインドは使わず、`AskUserQuestion`
による選択肢提示で対話を実現する。クリップボードコピーは
「`c` 押下を待つ」代わりに **`AskUserQuestion` の選択肢** として提示され、
ユーザが明示的に選んだときだけ実行される（自動コピーは行わない）。

## aggregate.sh の引数

| 引数 | 役割 |
|------|------|
| `-SessionId <UUID>` | 集計対象セッション（省略時は env / 最新 mtime） |
| `-ProjectKey <key>` | プロジェクトキー（省略時は cwd から自動導出） |
| `-Stdout` | UTF-8 で stdout に直接書き出し（Bash 経由用） |
| `-Copy` | 整形済み文字列をクリップボードへコピー |
| `-AsObject` | 整形済み文字列ではなく集計結果オブジェクトを返す |

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

[MIT License](LICENSE)

## 著者

dmajima
