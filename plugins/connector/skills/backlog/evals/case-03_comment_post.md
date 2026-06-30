# Case 03: コメント投稿（render-check PASS → 承認 → POST）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PROJ-123 にこの調査結果をコメント投稿して"（投稿本文は会話中に提示済み） |
| 引数 | 課題キー `PROJ-123` + 投稿本文（スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に対象スペースのエントリあり / プロジェクト PROJ の textFormattingRule は `markdown` / 本文に記法不一致・機密情報なし |

## 期待動作

### Phase 1: 認証事前確認

- `example.backlog.jp` を credentials.json の `domains` と照合し、API キーの存在を確認する

### Phase 2: 操作種別判定

- 「コメント投稿」を **書き込み** と判定し、SKILL.md Step 4（書き込み系の実行）へ進む

### Phase 3: 記法判定

- `GET /api/v2/projects/PROJ` で `textFormattingRule` を取得し、`"markdown"` と判定する
- render-check のターゲットを `backlog-markdown` に決定する（推測で決めない）

### Phase 4: render-check ゲート（必須）

- 投稿本文 + ターゲット `backlog-markdown` で `render-check` スキルを実行する
- 5 カテゴリ（NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）全てが検査され、総合判定 **PASS** が返る
- 投稿プレビュー（レンダリング後の見え方の説明付き）が提示される

### Phase 5: 承認

- 投稿先（PROJ-123）・操作内容（コメント投稿）・確定本文を提示し、`AskUserQuestion` で承認を得る
- ユーザーが承認を選択する（未承認のまま POST しない）

### Phase 6: 投稿の実行

- `POST /api/v2/issues/PROJ-123/comments` を呼び出す（Content-Type: application/x-www-form-urlencoded）
- 本文は一時ファイル（mktemp + chmod 600）に書き込み、`--data-urlencode "content@${CONTENT_FILE}"` で送信する（シェル変数の直接埋め込み禁止）
- apiKey は `--config` ファイル経由・`--max-time 30`・HTTP コード分岐は safe-api-access.md セクション 5 に従う

### Phase 7: 結果検証・報告

- レスポンスの `id` を確認し、コメント URL `https://example.backlog.jp/view/PROJ-123#comment-{id}` を組み立てて報告する
- 一時ファイル（本文・curl config・レスポンス）は trap で削除する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（Backlog 側にコメントが 1 件作成される。ローカル一時ファイルは削除済み） |
| 標準出力（要約） | render-check 結果（PASS）→ 承認質問 → 投稿完了報告（コメント URL 付き） |
| 終了状態 | 成功（続けてステータス変更等が必要かを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは 操作種別 = 書き込み（コメント本文あり）である。本文を伴う書き込みは render-check ゲート（Phase 4）と AskUserQuestion 承認（Phase 5）の両方を通過するまで POST が発行されない。

## 関連ケース

- `case-06_render_check_fail.md`（同じコメント投稿で render-check が FAIL になり、修正 → 再チェックを経由する）
- `case-04_status_update.md`（本文なしの書き込み。render-check は不要だが承認は必須）
- `case-01_issue_get.md`（同じ課題への読み取り。ゲートなしで API を呼ぶ対比）
