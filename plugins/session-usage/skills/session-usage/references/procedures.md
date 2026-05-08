# 実行手順詳細

`session-usage` スキルの動作手順を詳細化する。SKILL.md の実行フローを補足する。

## ステップ 1: 引数解釈

`$ARGUMENTS` を以下のルールで解釈する。

| パターン | 処理 |
|---------|------|
| 空 | `SessionId` 未指定で `aggregate.ps1` / `tui.ps1` を起動 |
| 36 文字の UUID 形式 (`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`) | `SessionId` として渡す |
| その他 | 警告出力後、空扱いで進行（誤入力対策） |

UUID 検証は呼び出し元（commands/session-usage.md）で行うことを推奨する。
スクリプト本体（aggregate.ps1）も Test-Path で実在チェックを行うため二重防御となる。

## ステップ 2: TUI ランチャー起動

Bash 経由で以下を実行する:

```bash
pwsh -NoProfile -ExecutionPolicy Bypass \
     -File "${CLAUDE_PLUGIN_ROOT}/skills/session-usage/scripts/tui/launch.ps1" \
     [-SessionId <UUID>]
```

`launch.ps1` は以下の手順で動く:

1. `wt.exe`（Windows Terminal）の存在を確認
2. 存在すれば: `wt -w 0 nt --title "Claude Code Session Usage" pwsh -File tui.ps1 ...`
3. 無ければ: `Start-Process -FilePath pwsh -ArgumentList ...` で新規 conhost ウィンドウ
4. 起動後即座に呼び出し元へ復帰

## ステップ 3: TUI 動作

新規ウィンドウで動く `tui.ps1` の挙動:

1. 起動時に `aggregate.ps1` を呼び出し、整形済み文字列を取得
2. `Clear-Host` でフルスクリーンクリア
3. 集計結果を表示
4. フッターに操作ヒント `[c] Copy clipboard   [r] Refresh   [q] Quit (or ESC)`
5. `[System.Console]::ReadKey($true)` でキー入力待ち
6. キーに応じて以下を実行:

| キー | 動作 |
|-----|------|
| `c` / `C` | 整形済み文字列を `Set-Clipboard` でクリップボードへ。フッター上に "[OK] Copied to clipboard" を緑色表示 |
| `r` / `R` | `aggregate.ps1` を再実行して画面更新。"[OK] Refreshed at HH:mm:ss" を緑色表示 |
| `q` / `Q` / ESC | TUI を終了（ウィンドウを閉じる） |
| その他 | 無視 |

## ステップ 4: エラー処理

| 状況 | 動作 |
|------|------|
| プロジェクトディレクトリが見つからない | `aggregate.ps1` が throw → tui.ps1 の `Invoke-Aggregate` がエラーメッセージを `[ERROR]` で表示 |
| 指定 UUID の JSONL が見つからない | 同上 |
| stdin が閉鎖されている（誤って Bash で直接 tui.ps1 を起動した等） | tui.ps1 が警告を出して 5 秒後に終了 |
| `wt.exe` も `pwsh` も無い | launch.ps1 がエラー終了（通常は発生しない） |

## 関連スキル / コマンド

- 呼び出し元コマンド: `commands/session-usage.md`
- 比較対象: Claude Code 組み込み `/usage`（時間枠ベース）、`/doctor`（環境診断）

## 利用例

### 例 1: カレントセッションを TUI 表示

```text
/session-usage
→ 別ウィンドウで TUI 起動
→ c キーで整形済み結果がクリップボードへ
```

### 例 2: 特定セッションを集計

```text
/session-usage 0988238f-3cbe-4a35-9981-cb523f7ef3d1
→ 別ウィンドウで指定セッションの集計が表示される
```

### 例 3: 自然言語起動

```text
ユーザ「今回のセッションでどれくらいトークン使ったか教えて」
→ session-usage スキルが起動 → TUI ウィンドウ
```
