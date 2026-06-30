# case-08: callSummary が null（AI 要約未生成）

## 入力

```
ailead の共有リンクからデータを取得して
https://dashboard.ailead.app/share/<有効な share-key>
```

## 前提条件

- 共有リンクが有効（期限内）
- 文字起こしは正常に存在
- GraphQL レスポンスの `externalShare.callSummary` が **値 `null` で存在**する（AI 会議要約が未生成の会議）

## 期待される動作

### Phase 1: URL 確認
- 引数から `dashboard.ailead.app/share/` パターンの URL を検出
- share key を抽出

### Phase 2: セッション作業領域準備
- `.claude/.local/work/{yyyyMMdd_nn_ailead_fetch}/workspace/` を作成
- venv 構築（`setup_venv.sh`）

### Phase 3: データ取得
- `fetch_share.py` を venv の Python で実行
- GraphQL API が HTTP 200 で応答し、`data.externalShare` が存在、`errors` なし
- `build_transcript_text` が transcripts を時刻昇順で正常出力（callSummary の有無に影響されない）
- `build_summary_md` が `callSummary: null` を検出し「要約データなし」の `summary.md` を出力
- `build_metadata` が **AttributeError を起こさず** `topicCount: 0` の `metadata.json` を出力
  - `(share.get("callSummary") or {}).get("topics") or []` の `or` ガードで None を安全に吸収

### Phase 4: 結果報告
- 4 ファイルすべて（`response.json` / `transcript.txt` / `summary.md` / `metadata.json`）が正常出力
- ユーザーに以下を報告:
  - データ取得は成功したこと
  - AI 要約が未生成のため、`topicCount: 0` であること

### Phase 5: クリーンアップ
- venv 削除（`teardown_venv.sh`）

## 期待される出力

| ファイル | 期待値 |
|---------|-------|
| `workspace/response.json` | GraphQL レスポンス全文（`externalShare.callSummary` が `null`） |
| `workspace/transcript.txt` | 文字起こし全文（時刻昇順。callSummary null の影響なし） |
| `workspace/summary.md` | `# 会議要約` + `要約データなし` |
| `workspace/metadata.json` | `topicCount: 0` を含む。`title`, `participants`, `transcriptCount` 等は正常値 |
| 終了状態 | 成功（exit 0。正常系として処理続行） |

## 分岐根拠

`fetch_share.py` の `build_summary_md`: `share.get("callSummary") or {}` により `callSummary` が `null` の場合は空辞書にフォールバックし、`if not summary:` で `"要約データなし"` を出力する。`build_metadata` の `(share.get("callSummary") or {}).get("topics") or []` は `callSummary` が `null` でも AttributeError を起こさない（`dict.get(key)` は値が `None` の場合 `None` を返すため `or {}` ガードが必須）。

## 関連ケース

- `case-01_share_fetch_success.md`（callSummary が存在する正常パス）
- `case-05_empty_transcript.md`（transcripts が空の場合の部分成功パス）
- `case-09_transcripts_unordered.md`（callSummary null との複合条件でもソートは同様に機能する）
