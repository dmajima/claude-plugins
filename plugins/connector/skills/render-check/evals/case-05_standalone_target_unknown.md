# Case 05: 単体起動でターゲット記法が不明（AskUserQuestion で確認してからチェック）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "このコメントが Backlog で正しく表示されるかチェックして"（単体起動） |
| 起動経路 | 単体起動（`backlog` / `azure` スキルを経由しない） |
| 引数 | 本文（下記）のみ。投稿先は Backlog と分かるが `textFormattingRule` が不明 |
| フラグ | なし |
| 既存状態 | 対象プロジェクトの記法設定を呼び出し元から引き継いでいない（API 判定値なし） |

### チェック対象本文（行番号は先頭行を 1 行目として数える）

````text
動作確認は **完了** しています。リリース可能です。
````

## 期待動作

### Phase 1: 入力確定（ターゲット確認）
- ターゲットが Backlog と分かるが記法（`backlog-notation` / `backlog-markdown`）が未確定のため、**推測でチェックを開始しない**
- AskUserQuestion でターゲット種別を確認する
  - 選択肢 1: `backlog-notation`（プロジェクト設定の textFormattingRule が「Backlog 記法」）
  - 選択肢 2: `backlog-markdown`（プロジェクト設定の textFormattingRule が「Markdown」）
- ユーザーが `backlog-notation` を選択する

### Phase 2: チェック実行
- 前処理: `{code}` ブロックが存在しないため本文全体を地の文として扱う
- NOTATION: backlog-notation.md セクション 3 のパターンで 1 件を検出する
  - 1 行目: `**完了**`（Markdown 太字）= FAIL（Backlog 記法では装飾されず `**` がそのまま表示される）
- AUTOLINK / STRUCTURE / SECRET / SIZE: 検出なし（5 カテゴリ全てを実施する）

### Phase 3: 結果レポート
- NOTATION FAIL 1 件の表（1 行目）+ 総合判定 FAIL を提示する

### Phase 4: 修正提案と採用確認
- 変換表に基づく修正案を提示する: `**完了**` → `''完了''`
- AskUserQuestion で確認する（選択肢: 「修正案を採用して再チェック」/「採用せず終了（レポートのみ）」。単体起動のため投稿の選択肢自体が存在しない）
- ユーザーが「採用せず終了（レポートのみ）」を選択する

### Phase 5: 終了
- FAIL の結果レポートを提示して終了する（単体起動のため投稿は行わない）
- FAIL を「投稿可」と表現しない（レポートには「このまま投稿すると `**` が文字として表示される」旨を残す）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（render-check はファイルを生成しない） |
| 標準出力（要約） | ターゲット確認の AskUserQuestion → NOTATION FAIL 1 件の表 + 総合判定 FAIL + 変換案（`''完了''`）の提示 |
| 終了状態 | 成功（FAIL レポート提示で終了・投稿なし） |

## 分岐の根拠

このケースが分岐するトリガーは 入力のターゲット = 未確定（単体起動かつ Backlog の記法設定が不明）である。SKILL.md の入力ルール「単体起動でターゲットが Backlog かつ記法不明の場合はユーザーに確認する（推測で決めない）」により、チェック実行前に AskUserQuestion が必ず先行する。本ケースの本文は `backlog-markdown` なら太字として正しく表示されるため、ターゲットを推測すると判定が逆転する（確認が必須である根拠）。

## 関連ケース

- `case-01_backlog_notation_fail.md`（ターゲット確定後の NOTATION FAIL 処理は同種。呼び出し元ゲート経由のため確認が不要な点が異なる）
- `case-06_structure_fail.md`（同じ単体起動でも、発話でターゲットが明示されていれば確認の AskUserQuestion は発火しない）
