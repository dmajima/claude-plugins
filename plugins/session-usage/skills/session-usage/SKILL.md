---
name: session-usage
description: カレントセッション（または指定セッション）のトークン消費量を JSONL から直接集計し、対話 TUI（フルスクリーン + キー入力受付）で表示してクリップボードへコピーするスキル。「セッションのトークン使用量を見せて」「session-usage」「今回の消費量教えて」等で起動する。Use when reporting Claude Code session token consumption with interactive TUI. SKIP when needing only a one-shot text dump (use direct aggregate.ps1 invocation).
---

# session-usage

カレントセッション（または引数指定セッション）の JSONL を直接パースし、
トークン消費量を `/doctor` 風のレイアウトで表示する。
対話 TUI を新規ターミナルウィンドウで起動し、`c` キーでクリップボードへコピー、
`r` キーで再集計、`q` / ESC で終了できる。

## 責務

- セッション JSONL（`~/.claude/projects/<projectKey>/<sessionId>.jsonl`）の直接パース
- `type=assistant` レコードの `message.usage` 集計
- セッション名（custom-title / ai-title）、期間、リクエスト数の抽出
- 整形済み文字列の生成（罫線レイアウト・k tokens 単位・利用比率付き）
- 対話 TUI の新規ウィンドウ起動（Windows Terminal 優先、フォールバック pwsh）

## 責務外

- Anthropic API 課金額の計算（係数は内部仕様のため再現性が保証されない）
- 5h ウィンドウ・週次利用枠の集計（`/usage` 組み込みコマンドの守備範囲）
- リアルタイム監視・閾値超過アラート

## トリガー条件

明示要求トリガー:

- `/session-usage` コマンドからの呼び出し（最も一般的）
- 「セッションのトークン消費を表示して」「今のセッションの使用量見せて」等の自然言語

引数:

| 引数 | 解釈 |
|-----|------|
| 空 | カレントセッション（`$env:CLAUDE_CODE_SESSION_ID` → 最新 mtime の順で解決） |
| UUID 形式の文字列 | 該当 JSONL を集計対象とする |

## 前提

- Windows + PowerShell 7+ 環境（`pwsh` が PATH 上にある）
- Claude Code の JSONL ログ形式（`message.usage` フィールド構造）
- 新規ウィンドウ起動には Windows Terminal（推奨）または pwsh の Start-Process

## 実行フロー

### 1. パラメータ解決

引数 `$ARGUMENTS` が UUID 形式なら `SessionId` として渡す。それ以外（空 or 非 UUID）は無視。

### 2. TUI ランチャー起動

```text
pwsh -NoProfile -ExecutionPolicy Bypass `
     -File "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/tui/launch.ps1" `
     [-SessionId <UUID>]
```

`launch.ps1` が新規ウィンドウで `tui.ps1` を起動し、即座に呼び出し元へ復帰する。
TUI ウィンドウは独立して動作し、`c` / `r` / `q` キーを受け付ける。

### 3. 補助出力（Claude Code 内）

別ウィンドウを開いた事実と、操作方法（c=copy, r=refresh, q=quit）を 1 行ずつ表示する。
Claude Code 内に集計結果を残したい場合は、`-AsObject` オプションなしで `aggregate.ps1`
を直接実行すれば整形済み文字列のみを得られる（TUI なし）。

## 重要な制約

- **stdin が閉じている環境（Claude Code Bash 経由）では対話 TUI は動作しないため、
  必ず新規ウィンドウで起動する**（同一プロセスでの実行は `launch.ps1 -NoNewWindow` 用）
- **集計対象は `type=assistant` レコードのみ**。他のレコード（user / system / attachment 等）
  はトークン消費に計上しない
- **Cache Read は累計で大きく見える**（同じトークンを毎リクエスト読み出すため）。これは
  「コスト」ではなく「処理されたトークン量の総和」として理解する
- **外部依存なし**: ccusage 等のサードパーティを使わず、PowerShell 標準機能のみで実装

## 参照

| 用途 | ファイル |
|-----|---------|
| 集計ロジック実装 | `scripts/aggregate/aggregate.ps1` |
| 対話 TUI 実装 | `scripts/tui/tui.ps1` |
| 新規ウィンドウ起動 | `scripts/tui/launch.ps1` |
| 実行手順詳細 | [`references/procedures.md`](references/procedures.md) |
| TUI 仕様詳細 | [`references/tui-spec.md`](references/tui-spec.md) |
