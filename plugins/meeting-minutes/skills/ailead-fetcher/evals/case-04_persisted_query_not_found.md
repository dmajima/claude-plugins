# Case 04: PERSISTED_QUERY_NOT_FOUND（ハッシュ形式不一致）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ailead の共有リンクからデータを取得して https://dashboard.ailead.app/share/<key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内だが、ailead 側の API 仕様変更により `extensions.operationHash` 形式自体が不整合を起こしている |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを取得し、`buildId` を正規表現で抽出する
3. `fetch_share.py` の `try_known_hashes` で既知の `operationHash` を順に試行する
4. 全ての既知ハッシュに対して `PERSISTED_QUERY_NOT_FOUND` エラーが返されることを検出する
5. `try_known_hashes` が `(None, None)` を返し、JS チャンクからの再抽出フローに移行する:
   - HTML ソース内の `<script>` タグから `pages/share/%5Bkey%5D-*.js` パターンの JS URL を検索する
   - JS チャンクを取得し、`externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"` で抽出を試みる
6. JS チャンクからもハッシュ形式が変更されており、正規表現にマッチしないため `extract_operation_hash_from_js` が `None` を返す
7. スクリプトが `sys.exit(1)` で終了し、stderr に `"ERROR: Could not extract operationHash from JS chunk."` を出力する
8. ユーザーに以下を報告する:
   - operationHash の自動抽出に失敗したこと
   - ailead 側の API 仕様が変更された可能性があること
   - `references/api-spec.md` セクション2「operationHash の取得」の正規表現パターンを確認・更新する必要があること

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（エラーのため出力しない） |
| stderr | `ERROR: Could not extract operationHash from JS chunk.` |
| ユーザーへの通知 | 「operationHash の自動抽出に失敗しました。ailead の API 仕様が変更された可能性があります。`references/api-spec.md` の正規表現パターンの更新が必要です。」等のエラーメッセージ |
| 終了状態 | エラー終了（`sys.exit(1)`。ユーザーに原因と対処を明示） |

## 分岐の根拠

`fetch_share.py` の `try_known_hashes`: 既知ハッシュの `query_graphql` 呼び出しでレスポンスの `errors[0].extensions.code` が `PERSISTED_QUERY_NOT_FOUND` の場合、そのハッシュをスキップして次を試行する。全ハッシュが失敗すると `(None, None)` を返す。続いて `extract_operation_hash_from_js` を呼ぶが、JS チャンク内のハッシュ形式が正規表現パターンと不一致の場合 `None` を返し、`sys.exit(1)` に到達する。`references/procedures.md` エラーハンドリング表: 「`PERSISTED_QUERY_NOT_FOUND`: ハッシュ形式の不一致 → `extensions.operationHash` 形式であることを確認」。

## 関連ケース

- `case-02_hash_outdated.md`（`CLIENT_CODE_OUT_OF_DATE` エラー後に JS チャンクから再抽出が成功するケース）
- `case-01_success.md`（既知ハッシュが有効な正常パス）
- `case-03_expired_link.md`（リンク自体が無効な場合）
