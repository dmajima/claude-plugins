# Case 01: 課題取得（読み取り）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog で PROJ-123 の内容とコメントを見せて" |
| 引数 | 課題キー `PROJ-123`（スペースは過去の会話・課題 URL から `example.backlog.jp` と特定できる） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `domains` に `example.backlog.jp` を含む API キーエントリ（`value` 非空）が存在する |

## 期待動作

### Phase 1: 認証事前確認

- 対象スペースのホストを `example.backlog.jp` に確定する
- `~/.claude/credentials.json` の各エントリの `domains` と `example.backlog.jp` を照合し、一致エントリの `value` が非空であることを確認する（credentials-precheck.md）
- API キーのフル値は会話出力しない

### Phase 2: 操作種別判定

- 「課題取得 + コメント取得」を **読み取り** と判定し、SKILL.md Step 3（読み取り系の実行）へ進む
- render-check・AskUserQuestion 承認は発火しない（書き込みではないため）

### Phase 3: API 呼び出し

- `GET /api/v2/issues/PROJ-123` で課題本体を取得する
- `GET /api/v2/issues/PROJ-123/comments?order=desc&count=20` でコメントを取得する
- いずれも safe-api-access.md の原則に従う: `curl --max-time 30`、apiKey は `--config` ファイル経由で渡す、HTTP コードを `-w '%{http_code}'` で取得して分岐する
- HTTP 2xx を受領し、一時ファイル（curl config・レスポンス）は trap で削除する

### Phase 4: 整形報告

- `課題キー / 件名 / ステータス / 担当者 / 期限 / 更新日時` + 本文要約 + コメント一覧（投稿者 / 日時 / 本文。`content` が null のコメントは変更ログとして変更内容を要約）を提示する
- 課題 URL `https://example.backlog.jp/view/PROJ-123` を添える
- レスポンスの生 JSON をそのまま貼らない。`apiKey=` を含む URL はマスクして扱う

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（一時ファイルは処理終了時に削除済み） |
| 標準出力（要約） | 課題 PROJ-123 の件名・ステータス・担当者・本文要約・コメント一覧と課題 URL の整形報告 |
| 終了状態 | 成功（続けて関連操作が必要かを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは 操作種別（SKILL.md Step 2） = 読み取り（課題取得・コメント取得）である。Step 3 の読み取り経路に進み、Step 4 の書き込みゲート（render-check・承認）は経由しない。

## 関連ケース

- `case-02_issue_search.md`（同じ読み取り系だが、プロジェクトキー → projectId 数値解決を経由する検索操作）
- `case-03_comment_post.md`（同じ課題に対する書き込み系。render-check + 承認ゲートが追加される）
- `case-05_credentials_missing.md`（Phase 1 の認証事前確認で解決できず、API を呼ばず対話取得フォールバックへ分岐する。中止選択時のみ終了）
