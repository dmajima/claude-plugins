---
name: session-usage
description: カレントセッション（または指定セッション）のトークン消費量を JSONL から直接集計し、Claude UI の対話ループ（AskUserQuestion）でクリップボードコピー・再集計・終了を選択できるスキル。「セッションのトークン使用量を見せて」「session-usage」「今回の消費量教えて」等で起動する。Use when reporting Claude Code session token consumption interactively in the Claude UI. SKIP when only a one-shot dump suffices (call aggregate.ps1 directly).
---

# session-usage

カレントセッション（または引数指定セッション）の JSONL を直接パースし、
トークン消費量を `/doctor` 風レイアウトで Claude UI に表示する。
表示と同時に整形済み文字列をクリップボードへ自動コピーし、
`AskUserQuestion` による対話ループで「再集計 / 終了」を選択させる。

## 責務

- セッション JSONL（`~/.claude/projects/<projectKey>/<sessionId>.jsonl`）の直接パース
- `type=assistant` レコードの `message.usage` 集計
- セッション名（custom-title / ai-title）、期間、リクエスト数の抽出
- 整形済み文字列の生成（罫線レイアウト・k tokens 単位・利用比率付き）
- 整形済み文字列の自動クリップボードコピー
- `AskUserQuestion` による対話ループ（再集計 / 終了の選択）

## 責務外

- 別ウィンドウ TUI の起動（旧仕様。Claude UI 内対話で代替済み）
- Anthropic API 課金額の計算（係数は内部仕様のため再現性が保証されない）
- 5h ウィンドウ・週次利用枠の集計（`/usage` 組み込みコマンドの守備範囲）

## トリガー条件

明示要求トリガー:

- `/session-usage` コマンドからの呼び出し
- 「セッションのトークン消費を表示して」「今のセッションの使用量見せて」等の自然言語

引数:

| 引数 | 解釈 |
|-----|------|
| 空 | カレントセッション（`$env:CLAUDE_CODE_SESSION_ID` → 最新 mtime の順で解決） |
| 36 文字 UUID 形式 | 該当 JSONL を集計対象とする |
| その他 | 警告後、空扱いで進行 |

## 前提

- Windows + PowerShell 7+ 環境（`pwsh` が PATH 上にある）
- Claude Code の JSONL ログ形式（`message.usage` フィールド構造）

## 実行フロー

### 1. 引数解釈

`$ARGUMENTS` を UUID 形式チェックする。UUID 形式なら `SessionId` として渡し、
それ以外は無視。

### 2. 集計実行 + 表示 + 自動コピー

Bash 経由で以下を実行する:

```bash
pwsh -NoProfile -ExecutionPolicy Bypass \
  -File "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/aggregate/aggregate.ps1" \
  -Stdout -Copy [-SessionId <UUID>]
```

- `-Stdout`: stdout へ UTF-8 直接書き出し（Bash 経由でも罫線・日本語が文字化けしない）
- `-Copy`: 整形済み文字列を `Set-Clipboard` でクリップボードへ
- 末尾に `[OK] clipboard へコピーしました` の通知が付く

Bash の標準出力はそのまま Claude UI に表示される。

### 3. 対話ループ（AskUserQuestion）

集計結果を表示した後、`AskUserQuestion` で次のアクションを尋ねる:

- 「再集計」: 進行中のセッションは値が増えるため、最新値を見たい場合に選択
- 「終了」: 対話を終える

「再集計」が選ばれたら手順 2 に戻る。「終了」が選ばれたら、または何も選ばれず
普通に応答が続けば、対話を終える。

## 重要な制約

- **Claude UI の Bash は stdin 閉鎖**: `[System.Console]::ReadKey()` 等の対話キー入力は不可。
  操作選択は `AskUserQuestion` に集約する
- **集計対象は `type=assistant` レコードのみ**。他のレコード（user / system / attachment 等）
  はトークン消費に計上しない
- **Cache Read は累計で大きく見える**（同じトークンを毎リクエスト読み出すため）。これは
  「コスト」ではなく「処理されたトークン量の総和」として理解する
- **外部依存なし**: ccusage 等のサードパーティを使わず、PowerShell 標準機能のみで実装

## 参照

| 用途 | ファイル |
|-----|---------|
| 集計ロジック実装 | `scripts/aggregate/aggregate.ps1` |
| 実行手順詳細 | [`references/procedures.md`](references/procedures.md) |
