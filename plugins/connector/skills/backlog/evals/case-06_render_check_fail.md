# Case 06: render-check FAIL → 修正採用 → 再チェック PASS → 投稿

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PROJ-456 にこのレビュー結果をコメント投稿して"（投稿本文に Markdown 見出し `## 確認結果` を含む） |
| 引数 | 課題キー `PROJ-456` + 投稿本文（スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に対象スペースのエントリあり / プロジェクト PROJ の textFormattingRule は `backlog`（Backlog 記法） |

## 期待動作

### Phase 1: 認証事前確認 + 操作種別判定

- `example.backlog.jp` の API キーを credentials.json の `domains` 照合で確認する
- 「コメント投稿」を書き込みと判定し、SKILL.md Step 4 へ進む

### Phase 2: 記法判定

- `GET /api/v2/projects/PROJ` で `textFormattingRule = "backlog"` を取得し、render-check のターゲットを `backlog-notation` に決定する

### Phase 3: render-check 1 回目（FAIL）

- 投稿本文 + ターゲット `backlog-notation` で `render-check` スキルを実行する
- NOTATION カテゴリで行頭 `## `（Markdown 見出し）の混入を検出する: Backlog 記法スペースではレンダリングされず、そのまま文字として表示されるため **FAIL**（backlog-notation.md セクション 3 の検出パターン `^#{1,6} `）
- 総合判定 **FAIL**（投稿不可）となり、この時点では POST を発行しない

### Phase 4: 修正案の提示と採用

- backlog-notation.md セクション 4 の変換表に基づき、`## 確認結果` を `** 確認結果`（Backlog 記法の見出し 2）へ変換した修正済み本文を提示する
- `AskUserQuestion` で修正案の採用可否を確認し、ユーザーが採用を選択する
- FAIL のまま投稿を強行する選択肢は提示しない（render-check SKILL.md Step 5: FAIL 強行の選択肢は提示しない）

### Phase 5: 再チェック（PASS）

- 修正後本文で 5 カテゴリ **全て** を再チェックする（NOTATION のみの部分再検査をしない）
- 総合判定 **PASS** が返る

### Phase 6: 承認と投稿

- 投稿先（PROJ-456）・操作内容（コメント投稿）・確定本文（修正後）を提示し、`AskUserQuestion` で投稿の承認を得る
- 承認後に `POST /api/v2/issues/PROJ-456/comments` を実行する（本文は `--data-urlencode "content@${CONTENT_FILE}"` で送信）

### Phase 7: 結果検証・報告

- レスポンスの `id` を確認し、コメント URL `https://example.backlog.jp/view/PROJ-456#comment-{id}` を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（Backlog 側に修正後本文のコメントが 1 件作成される） |
| 標準出力（要約） | render-check 結果表（NOTATION FAIL・該当行付き）→ 修正案提示と採用確認 → 再チェック PASS → 投稿承認 → 投稿完了報告（コメント URL 付き） |
| 終了状態 | 成功（投稿されるのは修正後本文。元の Markdown 見出しのまま投稿されることはない） |

## 分岐の根拠

このケースが分岐するトリガーは render-check の総合判定 = FAIL（NOTATION: Backlog 記法プロジェクトへの Markdown 見出し混入）である。case-03（PASS で承認へ直行）と異なり、修正案提示 → ユーザー採用 → 全カテゴリ再チェックのループを経て、PASS になるまで POST が発行されない。

## 関連ケース

- `case-03_comment_post.md`（render-check が 1 回目で PASS し、修正ループなしで承認へ進む対比）
- `case-04_status_update.md`（本文なしの書き込みで render-check 自体が不要なケース）
