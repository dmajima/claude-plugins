# Case 05: 空の transcripts（文字起こし未完了）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead リンクから議事録を作って https://dashboard.ailead.app/share/<key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内。GraphQL 呼び出しは成功するが、レスポンスの `externalShare.transcripts` が空配列 `[]` |
| サーバー状態 | 録画直後で文字起こし処理が未完了。`callTasks` の `TRANSCRIPT` ステータスが `PENDING` または `PROCESSING` |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを取得し、`buildId` を抽出する
3. 既知の `operationHash` で GraphQL API を呼び出す
4. レスポンスを正常に受信する（HTTP 200 + `data.externalShare` が存在、`errors` なし）
5. `build_transcript_text` が空の `transcripts` 配列を処理し、空文字列を返す
6. `workspace/transcript.txt` を空ファイル（0 byte）として出力する
7. `workspace/response.json`、`workspace/summary.md`、`workspace/metadata.json` は通常どおり出力する
8. `metadata.json` の `transcriptCount` が `0` であることを確認する
9. ユーザーに以下を報告する:
   - GraphQL API の呼び出しは成功したが、文字起こしデータが空であること
   - ailead 側で文字起こし処理が未完了の可能性があること（`callTasks` の `TRANSCRIPT` ステータスを根拠に説明）
   - 数分〜数十分後に再試行することを提案する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/response.json` | GraphQL レスポンス全文（`externalShare.transcripts` が空配列 `[]`） |
| `workspace/transcript.txt` | 空ファイル（0 byte） |
| `workspace/summary.md` | AI 会議要約（`callSummary` が存在する場合はその内容。存在しない場合は「要約データなし」） |
| `workspace/metadata.json` | `transcriptCount: 0` を含む。その他メタデータ（`title`, `startDatetime`, `duration` 等）は正常値 |
| ユーザーへの通知 | 「文字起こしデータが空です。ailead 側で文字起こし処理が未完了の可能性があります。数分後に再試行してください。」等の案内 |
| 終了状態 | 部分成功（ファイルは出力するが、transcript.txt が空のため議事録作成には進めない） |

## 分岐の根拠

`references/procedures.md` エラーハンドリング表: 「空の `transcripts`: 文字起こし未完了 → `callTasks` の `TRANSCRIPT` ステータスを確認」。`fetch_share.py` の `build_transcript_text` は `transcripts` 配列をイテレーションするため、空配列の場合は空文字列を返し、空ファイルが出力される。`references/api-spec.md` セクション3 の `callTasks` フィールド解説: 処理タスクのステータスとして `RECORD`/`TRANSCRIPT`/`SUMMARY`/`EXTRACT`/`CONVERT` が存在し、各タスクの完了状態が取得可能。

## 関連ケース

- `case-01_success.md`（transcripts が存在する正常パス）
- `case-03_expired_link.md`（リンク自体が無効な場合）
