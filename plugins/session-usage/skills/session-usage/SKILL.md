---
name: session-usage
description: カレントセッション（または指定セッション）のトークン消費量を JSONL から直接集計し、Claude UI の対話ループ（AskUserQuestion）でクリップボードコピー・再集計・終了を選択できるスキル。「セッションのトークン使用量を見せて」「session-usage」「今回の消費量教えて」等で起動する。Use when reporting Claude Code session token consumption interactively in the Claude UI. SKIP when only a one-shot dump suffices (call aggregate.ps1 directly).
---

# session-usage

カレントセッション（または引数指定セッション）の JSONL を直接パースし、
トークン消費量を `/doctor` 風レイアウトで Claude UI に表示する。
表示後は `AskUserQuestion` による対話ループで「クリップボードへコピー / 再集計 / 終了」
を選択できる（クリップボードコピーは選択時のみ実行され、自動コピーは行わない）。

## 責務

- セッション JSONL（`~/.claude/projects/<projectKey>/<sessionId>.jsonl`）の直接パース
- `type=assistant` レコードの `message.usage` 集計
- セッション名（custom-title / ai-title）、期間、リクエスト数の抽出
- 整形済み文字列の生成（罫線レイアウト・k tokens 単位・利用比率付き）
- `AskUserQuestion` による対話ループ（コピー / 再集計 / 終了の選択）
- 「コピー」選択時のみ `Set-Clipboard` 実行

## 責務外

- 自動クリップボードコピー（旧仕様。アクション化済み）
- 別ウィンドウ TUI の起動（旧仕様。Claude UI 内対話で代替済み）
- Anthropic API 課金額の計算
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

### 2. 集計実行（結果を Claude のコンテキストへ取得）

Bash 経由で以下を実行する:

```bash
pwsh -NoProfile -ExecutionPolicy Bypass \
  -File "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/aggregate/aggregate.ps1" \
  -Stdout [-SessionId <UUID>]
```

`-Stdout` のみ（`-Copy` は付けない）。**この時点ではクリップボードへのコピーは行わない**。

スクリプトの標準出力は Claude のコンテキストに取り込まれる。Claude UI 上の
Bash 出力エリアでは折りたたまれて表示される可能性があるが、内容は **次の
ステップで `AskUserQuestion` の `preview` フィールドに埋め込んで全文表示する**
ため、Bash 生出力の見え方は問題にしない。

### 3. 対話ループ（AskUserQuestion 3 択 + preview に結果埋め込み）

集計結果を Claude のコンテキストに取得した後、`AskUserQuestion` で次のアクションを尋ねる。
**各オプションの `preview` フィールドに集計結果（手順 2 の標準出力全文）を必ず埋め込む**
こと。これにより、ユーザは選択肢にフォーカスするだけで集計結果を全文確認できる。

```
AskUserQuestion({
  questions: [{
    question: "集計結果",
    header: "session-usage",
    options: [
      {
        label: "クリップボードへコピー",
        description: "整形済み結果を Set-Clipboard でコピーします",
        preview: "<aggregate.ps1 -Stdout の標準出力全文>"
      },
      {
        label: "再集計",
        description: "進行中の値を最新化して再表示します",
        preview: "<aggregate.ps1 -Stdout の標準出力全文>"
      },
      {
        label: "終了",
        description: "対話を終えます",
        preview: "<aggregate.ps1 -Stdout の標準出力全文>"
      }
    ],
    multiSelect: false
  }]
})
```

`preview` には改行を含むマルチライン文字列をそのまま渡せる。
3 オプションすべてに同じ集計結果テキストを設定し、どれをフォーカスしても
結果が右ペインに表示されるようにする。

選択に応じた動作:

| 選択 | アクション | 直後の挙動 |
|-----|-----------|-----------|
| クリップボードへコピー | `aggregate.ps1 -Copy [-SessionId ...]` を実行 | コピー成功通知後、再度 AskUserQuestion を提示 |
| 再集計 | 手順 2（`-Stdout` のみ）へ戻る | 再表示後、再度 AskUserQuestion を提示 |
| 終了 | 対話終了 | — |

「終了」が選ばれるまでループは継続する。コピーや再集計を選んだ後も、続けて
別のアクションを選べるようにする。

## 重要な制約

- **自動コピーは行わない**: 表示時点ではクリップボードに書き込まない。コピーは
  ユーザが `AskUserQuestion` で明示的に選んだときだけ実行する
- **Claude UI の Bash は stdin 閉鎖**: `[System.Console]::ReadKey()` 等の対話キー入力は不可。
  操作選択は `AskUserQuestion` に集約する
- **集計対象は `type=assistant` レコードのみ**
- **Cache Read は累計で大きく見える**（同じトークンを毎リクエスト読み出すため）
- **外部依存なし**: PowerShell 標準機能のみで実装

## 参照

| 用途 | ファイル |
|-----|---------|
| 集計ロジック実装 | `scripts/aggregate/aggregate.ps1` |
| 実行手順詳細 | [`references/procedures.md`](references/procedures.md) |
