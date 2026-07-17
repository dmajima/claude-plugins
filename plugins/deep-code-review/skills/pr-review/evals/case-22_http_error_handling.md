# case-22 HTTP エラーハンドリング（P15: 401 即停止 / 429 バックオフ / 5xx リトライ）

PR コメント投稿・情報取得の API 呼び出しが HTTP エラーを返すケース。connector 側のエラー処理と pr-review 側の停止・報告責務の分担を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（標準モード） |
| 想定シナリオ | (A) connector が 401/403 を返す / (B) connector が 429（レート制限）を返す / (C) connector が 5xx を返す |
| モード | 対話 |

## 分岐の根拠

references/skill-rules-matrix.md P15（全 API 呼び出しは HTTP コード取得 + case 分岐: 401-403 即停止 / 429 指数バックオフ / 5xx 単発リトライ）、`${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md`、`${CLAUDE_SKILL_DIR}/references/comment-posting.md` セクション 7.4（HTTP ステータス分岐とロールバック）。

## 期待動作

- シナリオ (A) 401/403: connector が認証エラーを返した場合、pr-review は **投稿を即停止** し、ユーザーに認証確認を案内する（comment-posting.md セクション 7.4「connector が認証エラー（401/403 相当）を返した場合: pr-review は投稿を即停止し、ユーザーに認証確認を案内する」）。リトライしない
- シナリオ (B) 429: HTTP エラーハンドリングは connector 側が担当し、指数バックオフを実施する（http-error-handling.md）。pr-review は connector からの最終結果（成功/失敗）を受けて、部分失敗時は未送信件数を完了報告（Step 8）に明示する
- シナリオ (C) 5xx: connector 側が単発リトライを実施し、なお失敗した場合は pr-review が未送信件数を報告する。部分失敗時は既存状態を巻き戻さず（コメント重複投稿を避ける）、未送信件数を完了報告に明示する（comment-posting.md セクション 7.4）
- いずれのシナリオでも認証情報の値をユーザーに表示しない（U12）
- 投稿失敗した finding は state.yaml に `post_failed: true` を付記し、次回レビュー時に再投稿を試みる（flow.md Step 8.5-4 の投稿失敗時処理）

## 関連ケース

- case-11: 認証情報欠落時のユーザー問い合わせ（API 不発行）
- case-10: 投稿順序（正常系）
