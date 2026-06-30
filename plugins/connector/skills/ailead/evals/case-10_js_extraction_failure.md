# case-10: 全 known hash 失敗 + JS チャンク再抽出も失敗

## 入力

```
ailead の共有リンクからデータを取得して
https://dashboard.ailead.app/share/<有効な share-key>
```

## 前提条件

- 共有リンクが有効（期限内）
- ailead 側の大規模デプロイにより、全ての `KNOWN_HASHES` が `PERSISTED_QUERY_NOT_FOUND` または `CLIENT_CODE_OUT_OF_DATE` を返す
- HTML ページに JS チャンク URL（`pages/share/%5Bkey%5D-*.js`）が存在しない、またはチャンク内に `externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"` パターンがマッチしない

## 期待される動作

### Phase 1-2: URL 確認・作業領域準備
- 通常通り実行

### Phase 3: データ取得
- `fetch_share.py` を venv の Python で実行
- `try_known_hashes` が全 `KNOWN_HASHES` を順に試行
- 各ハッシュに対して GraphQL API が `PERSISTED_QUERY_NOT_FOUND` または `CLIENT_CODE_OUT_OF_DATE` を返す
- 全ハッシュ失敗により `try_known_hashes` が `(None, None)` を返す
- JS チャンク再抽出フローに移行:
  - `extract_operation_hash_from_js` が以下のいずれかで `None` を返す:
    - HTML に `pages/share/%5Bkey%5D-*.js` パターンの URL が存在しない
    - JS チャンク取得でリダイレクトが検出された（safe-api-access ポリシー）
    - JS チャンク内に hash 正規表現がマッチしない
- stderr に `"ERROR: Could not extract operationHash from JS chunk."` を出力
- `sys.exit(1)` で終了

### Phase 4: 結果報告
- ユーザーに以下を報告:
  - operationHash の自動抽出に失敗したこと
  - ailead 側の API 仕様が変更された可能性があること
  - `references/api-spec.md` の operationHash 更新が必要であること

## 期待される出力

| ファイル | 期待値 |
|---------|-------|
| `workspace/` 配下 | なし（エラーのため出力しない） |
| stderr | `ERROR: Could not extract operationHash from JS chunk.` |
| 終了状態 | 失敗（exit 1） |

## 分岐根拠

`fetch_share.py` の `main()`: `try_known_hashes` が `(None, None)` を返した後、`extract_operation_hash_from_js` を呼ぶ。この関数が `None` を返す条件は 3 つ: (1) `js_match` が `None`（JS チャンク URL が HTML に不在）、(2) JS チャンク取得でリダイレクト検出、(3) `hash_match` が `None`（正規表現不一致）。いずれの場合も `main()` の `if not new_hash:` 分岐に到達し `sys.exit(1)` で終了する。case-02 は JS 抽出**成功**パスをカバーしており、本ケースは**失敗**パスをカバーする。

## 関連ケース

- `case-02_hash_outdated.md`（known hash 失敗後、JS チャンク抽出が成功するケース）
- `case-01_share_fetch_success.md`（known hash で成功する正常パス）
