# Evals: ailead-fetcher

`ailead-fetcher` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 分岐 | 概要 |
|--------|------|------|
| case-01_success | 正常取得 | 有効な共有 URL から GraphQL 成功し 4 ファイル出力する |
| case-02_hash_outdated | ハッシュ再抽出 | `CLIENT_CODE_OUT_OF_DATE` エラー時に JS チャンクから operationHash を再抽出する |
| case-03_expired_link | 期限切れ | HTTP 404 発生時にリンク期限切れエラーをユーザーに提示する |

## 実行確認方法

各ケースの「入力」セクションの条件で Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

## ケース追加ルール

新しいエラーパターンや取得フローの分岐を追加した場合は、対応するケースファイルを必ず追加する。
