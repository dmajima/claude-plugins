# Case 07: コメント投稿の承認で「中止」選択（POST を発行せず終了）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PROJ-123 にこのコメントを投稿して"（投稿本文は会話中に提示済み） |
| 引数 | 課題キー `PROJ-123` + 投稿本文（スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に対象スペースのエントリあり / プロジェクト PROJ の textFormattingRule は `markdown` / 本文に記法不一致・機密情報なし（render-check は PASS になる） |

## 期待動作

### Phase 1: 認証事前確認と操作種別判定

- `example.backlog.jp` を credentials.json の `domains` と照合し、API キーの存在を確認する
- 「コメント投稿」を **書き込み** と判定し、SKILL.md Step 4（書き込み系の実行）へ進む

### Phase 2: 記法判定と render-check ゲート

- `GET /api/v2/projects/PROJ` で `textFormattingRule = "markdown"` を取得し、render-check のターゲットを `backlog-markdown` に決定する
- 投稿本文 + ターゲット `backlog-markdown` で `render-check` スキルを実行し、総合判定 **PASS** が返る

### Phase 3: 承認（ユーザーが中止を選択）

- 投稿先（PROJ-123）・操作内容（コメント投稿）・確定本文を提示し、`AskUserQuestion` で承認を求める
- ユーザーが「中止」を選択する

### Phase 4: 中止の報告

- `POST /api/v2/issues/PROJ-123/comments` を **発行しない**（書き込み API リクエスト 0 件。render-check PASS 済みでも承認なしでは投稿しない）
- 「投稿を中止しました」と中止した操作内容（投稿先 PROJ-123・コメント投稿・本文は送信されていないこと）を報告して終了する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（Backlog 側にコメントは作成されない） |
| 標準出力（要約） | render-check 結果（PASS）→ 承認質問 → 「投稿を中止しました」+ 中止した操作内容（投稿先・操作種別・本文未送信）の報告 |
| 終了状態 | 中止（書き込み API リクエスト発行数 0） |

## 分岐の根拠

このケースが分岐するトリガーは AskUserQuestion の選択 = 中止 である。case-03 と承認質問の直前（render-check PASS）までは同一経路だが、ユーザーが承認ではなく中止を選択するため、POST が発行されずに終了する。

## 関連ケース

- `case-03_comment_post.md`（同じ承認質問でユーザーが承認を選択し、POST → コメント URL 報告まで進む対比）
- `case-06_render_check_fail.md`（投稿前に止まる位置の対比。こちらは render-check FAIL により承認質問の前で修正ループに入り、修正採用 → 再チェック PASS → 承認を経て投稿まで進む）
