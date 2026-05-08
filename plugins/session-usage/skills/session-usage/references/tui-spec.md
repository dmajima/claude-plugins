# TUI 仕様

対話 TUI（`scripts/tui/tui.ps1`）の表示・キーバインド仕様を定義する。

## 画面構成

```
[Body 領域]
  ╔══════════════════════════════════════════════════════╗
  ║  Claude Code  Session Usage                          ║
  ╚══════════════════════════════════════════════════════╝

  Session  : <セッション名> (auto / renamed)
  ID       : <UUID>
  Period   : YYYY-MM-DD HH:mm - HH:mm  (X.X h or X min)
  Requests : N

  ┌── Token Consumption ───────────────────────────────────┐
  │  Input               :        N.Nk tokens (  N.N%)  │
  │  Cache Creation      :        N.Nk tokens (  N.N%)  │
  │  Cache Read          :        N.Nk tokens (  N.N%)  │
  │  Output              :        N.Nk tokens (  N.N%)  │
  │                        ───────────────────────────   │
  │  Total               :        N.Nk tokens             │
  └────────────────────────────────────────────────────────┘

  ┌── Per-Model ───────────────────────────────────────────┐ (条件付)
  │  <model>                : N.Nk tokens / NN calls   │
  └────────────────────────────────────────────────────────┘

  ┌── Server Tools ────────────────────────────────────────┐ (条件付)
  │  Web Search Requests : NNNNNN                          │
  │  Web Fetch  Requests : NNNNNN                          │
  └────────────────────────────────────────────────────────┘

[Status 領域 (オプション)]
  ────────────────────────────────────────────────────────
  <status message: e.g. [OK] Copied to clipboard>
  ────────────────────────────────────────────────────────

[Footer 領域]
  [c] Copy clipboard   [r] Refresh   [q] Quit (or ESC)
```

## キーバインド

| キー | 動作 | フィードバック |
|------|------|--------------|
| `c` / `C` | クリップボードコピー | "[OK] Copied to clipboard" 緑色 |
| `r` / `R` | 再集計 | "[OK] Refreshed at HH:mm:ss" 緑色 |
| `q` / `Q` | 終了 | ウィンドウを閉じる |
| `ESC` | 終了 | 同上 |
| その他 | 無視 | 状態保持 |

## 色設計

| 要素 | 色 |
|------|---|
| Body（罫線含む集計内容） | デフォルト（白） |
| Footer 区切り線 | DarkGray |
| Footer 操作ヒント | Cyan |
| Status: 成功 | Green |
| Status: 失敗 | Red |
| Status: 通常通知 | DarkGray |

ANSI カラーは PowerShell 7+ の `Write-Host -ForegroundColor` で指定する。
Windows Terminal / conhost の両方でサポートされる。

## 表示更新ポリシー

- 起動時: Body + Footer を 1 度描画
- キー押下後: `Clear-Host` で全消去 → Body + Status + Footer を再描画
- ちらつき低減のため、未変更領域の差分更新は行わない（再描画コストは数ミリ秒）

## ウィンドウサイズ要件

- 推奨幅: 80 列以上（罫線が折り返さない最小幅）
- 推奨高: 30 行以上（Body 全体 + Footer が 1 画面に収まる）

ウィンドウが狭い場合は罫線が折り返して見栄えが崩れるが、機能は維持する。

## 起動環境別の動作

| 環境 | 動作 |
|------|------|
| Windows Terminal の新規タブ（`wt.exe` 経由） | 推奨。タブタイトルが "Claude Code Session Usage" になる |
| 新規 conhost ウィンドウ（`Start-Process pwsh`） | フォールバック。標準で動作 |
| Claude Code Bash で直接 tui.ps1 起動 | NG。stdin 閉鎖により ReadKey が失敗 → 警告表示後 5 秒で終了 |

## クリップボード仕様

`Set-Clipboard` cmdlet を利用する。

- フォーマット: プレーンテキスト（罫線含む整形済み文字列）
- 改行: `[Environment]::NewLine`（Windows なら CRLF）
- リッチテキスト・HTML 形式のコピーは行わない

## 終了コード

- 通常終了（q / ESC / 例外なし）: 0
- aggregate.ps1 の throw を受けて表示後終了: TUI は表示を維持し、ユーザの q 入力で 0 終了
- launch.ps1 でランチに失敗（pwsh / wt 両方欠如）: 1
