# Case 05: 認証情報なし（API を呼ばず停止）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog で OTHER-1 を取得して"（課題 URL から対象スペースは `otherspace.backlog.jp` と特定できる） |
| 引数 | 課題キー `OTHER-1` |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` は存在するが、`domains` に `otherspace.backlog.jp` を含むエントリがない（`example.backlog.jp` 用の別エントリのみ存在する） |

## 期待動作

### Phase 1: 認証事前確認（失敗）

- 対象スペースのホストを `otherspace.backlog.jp` に確定する
- credentials.json の全エントリの `domains` と照合し、一致エントリが 0 件であることを確認する
- 別スペース（`example.backlog.jp`）用の API キーを流用しない（credentials-precheck.md セクション 4: 別スペースのキー流用禁止）
- 「もしかしたら使えるかもしれない」等の推測で API を呼ばない

### Phase 2: 準備依頼と停止

- Backlog API へのリクエストを **1 件も発行せずに** `AskUserQuestion` で以下を提示する:
  - `~/.claude/credentials.json` に `otherspace.backlog.jp` 用のエントリ（API キー + `domains`）の追加が必要であること
  - API キーは Backlog の個人設定 > API から発行できること
- ユーザーが認証情報を準備するまで API 操作には進まず、スキルを停止する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 「`otherspace.backlog.jp` 用の認証情報が確認できない」旨 + credentials.json へのエントリ追加手順の提示 |
| 終了状態 | 停止（API リクエスト発行数 0。ユーザーの準備完了後に再実行を案内） |

## 分岐の根拠

このケースが分岐するトリガーは 認証事前確認（SKILL.md Step 1） = 失敗（credentials.json の `domains` 照合で一致エントリ 0 件）である。Step 2 以降（操作種別判定・API 呼び出し）には一切進まない。

## 関連ケース

- `case-01_issue_get.md`（同じ読み取り依頼で認証事前確認に成功し、Step 3 へ進む対比）
- `case-03_comment_post.md`（書き込み依頼でも Phase 1 の認証事前確認は同一。失敗すれば本ケースと同じく停止する）
