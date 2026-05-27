# Case 02: operationHash 期限切れ（JS チャンク再抽出）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ailead の共有リンクからデータを取得して https://dashboard.ailead.app/share/<key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内だが、ailead 側のデプロイ更新により既知の `operationHash` が無効化されている |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを取得し、`buildId` を正規表現で抽出する
3. 既知の `operationHash` で GraphQL API を呼び出す
4. レスポンスに `CLIENT_CODE_OUT_OF_DATE` エラーが含まれることを検出する
5. エラーを受けて JS チャンクからの `operationHash` 再抽出フローに移行する:
   - HTML ソース内の `<script>` タグから `pages/share/%5Bkey%5D-*.js` パターンの JS URL を特定する
   - JS チャンクを `Invoke-WebRequest` で取得する
   - 正規表現 `externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"` でハッシュを抽出する
6. 再抽出した `operationHash` で GraphQL API を再呼び出しする
7. 再呼び出しが成功した場合、通常どおり 4 ファイルを `workspace/` に出力する
8. 再抽出したハッシュ値をユーザーに通知する（`api-spec.md` の更新が必要な旨）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/response.json` | 再抽出ハッシュによる GraphQL レスポンス全文 |
| `workspace/transcript.txt` | 標準形式の文字起こし全文 |
| `workspace/summary.md` | AI 会議要約 |
| `workspace/metadata.json` | 会議メタデータ |
| ユーザーへの通知 | 「operationHash が更新されました。`references/api-spec.md` セクション7の既知ハッシュを更新してください」等の案内 |
| 終了状態 | 成功（リトライにより正常完了） |

## 分岐の根拠

`references/procedures.md` ステップ3: 「通常は api-spec.md セクション7に記載の既知ハッシュを使用する。取得失敗（`CLIENT_CODE_OUT_OF_DATE` エラー）時のみ以下で再抽出する」。`references/api-spec.md` セクション6「既知の制約」: 「operationHash の有効期限: ailead のデプロイごとに変更される可能性がある。取得失敗時は JS チャンクからハッシュを再抽出する」。`references/procedures.md` エラーハンドリング表の `CLIENT_CODE_OUT_OF_DATE` 行。

## 関連ケース

- `case-01_success.md`（既知ハッシュが有効な正常パス）
- `case-03_expired_link.md`（リンク自体が無効な場合）
