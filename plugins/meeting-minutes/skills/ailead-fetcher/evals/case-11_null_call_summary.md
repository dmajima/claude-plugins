# Case 11: callSummary が null（AI 要約なし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead リンクから議事録を作って https://dashboard.ailead.app/share/<key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内。GraphQL 呼び出しは成功するが、レスポンスの `externalShare.callSummary` が **値 `null` で存在**する |
| サーバー状態 | AI 会議要約が未生成の会議（transcripts は正常に存在） |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを取得し、`buildId` を抽出する
3. 既知の `operationHash` で GraphQL API を呼び出す
4. レスポンスを正常に受信する（HTTP 200 + `data.externalShare` が存在、`errors` なし）
5. `build_transcript_text` が transcripts を時刻昇順で出力する（callSummary の有無に影響されない）
6. `build_summary_md` が `callSummary: null` を検出し「要約データなし」の `summary.md` を出力する
7. `build_metadata` が **AttributeError を起こさず** `topicCount: 0` の `metadata.json` を出力する
   （`callSummary` キーが値 `null` で存在するため、`or {}` ガードで None を吸収する）
8. 4 ファイルすべて（`response.json` / `transcript.txt` / `summary.md` / `metadata.json`）が正常に出力され、exit 0 で終了する
9. ユーザーに以下を報告する:
   - データ取得は成功したこと
   - AI 要約が未生成のため、下流の minutes-composer は generic-flow（文字起こしからのゼロ構造化）に切替えること

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/response.json` | GraphQL レスポンス全文（`externalShare.callSummary` が `null`） |
| `workspace/transcript.txt` | 文字起こし全文（時刻昇順） |
| `workspace/summary.md` | `# 会議要約` + 「要約データなし」 |
| `workspace/metadata.json` | `topicCount: 0` を含む。その他メタデータ（`title`, `participants`, `transcriptCount` 等）は正常値 |
| 終了状態 | 成功（exit 0。正常系として処理続行） |

## 分岐の根拠

`references/procedures.md` エラーハンドリング表: 「`callSummary` が null（topicCount: 0）: AI 要約が未生成の会議 → 正常系として処理続行。下流の minutes-composer は generic-flow に切替える」。`fetch_share.py` の `build_metadata` は `(share.get("callSummary") or {}).get("topics")` の `or` ガードにより、`callSummary` キーが値 `null` で存在しても AttributeError を起こさない（`dict.get(key, default)` は値が `None` の場合 default を返さないため、`or` ガードが必須）。

## 関連ケース

- `case-01_success.md`（callSummary が存在する正常パス）
- `case-05_empty_transcripts.md`（transcripts が空の場合の部分成功パス）
