# Evals: ailead-fetcher

`ailead-fetcher` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|--------|------|-------------|
| case-01_success | 有効な共有 URL から GraphQL 成功し 4 ファイル出力する | 正常取得 |
| case-02_hash_outdated | `CLIENT_CODE_OUT_OF_DATE` エラー時に JS チャンクから operationHash を再抽出する | ハッシュ再抽出 |
| case-03_expired_link | HTTP 404 発生時にリンク期限切れエラーをユーザーに提示する | 期限切れ |
| case-04_persisted_query_not_found | `PERSISTED_QUERY_NOT_FOUND` エラー時に JS チャンク再抽出も失敗しユーザーにハッシュ更新を報告する | ハッシュ形式不一致 |
| case-05_empty_transcripts | GraphQL 成功だが transcripts が空の場合に空ファイル出力と再試行を提案する | 文字起こし未完了 |
| case-06_password_protected | パスワード保護リンクに対して未対応の旨をユーザーに報告する | パスワード保護 |
| case-07_no_url_interactive | URL 未指定時にユーザーに ailead 共有 URL を AskUserQuestion で確認する | URL なし → 対話 |

## 実行確認方法

各ケースの「入力」セクションの条件で Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいエラーパターンや取得フローの分岐を追加した場合は、対応するケースファイルを必ず追加する。
