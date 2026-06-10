# Case 12: transcripts が時刻順でないレスポンス

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead リンクから議事録を作って https://dashboard.ailead.app/share/<key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内。GraphQL 呼び出しは成功するが、レスポンスの `externalShare.transcripts` 配列が時刻順でない（例: `startTime` が 0.5 → 0.9 → 0.0 → 0.2 の順） |
| 補足 | 空テキスト（`text` が空文字・空白のみ・null）のセグメントが混在していてもよい |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを取得し、`buildId` を抽出する
3. 既知の `operationHash` で GraphQL API を呼び出す
4. レスポンスを正常に受信する
5. `build_transcript_text` が以下を行う:
   - 空テキストのセグメントをスキップする（出力しない）
   - `startTime * duration` で実秒数を算出する
   - **`startTime` 昇順にソート**してから各行を出力する
6. 4 ファイルすべてが正常に出力され、exit 0 で終了する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/transcript.txt` | 1 行目のタイムスタンプが最小、末行が最大（全行が時刻昇順） |
| 同上 | 空テキストセグメントの行が存在しない |
| `workspace/metadata.json` | `transcriptCount` はレスポンスのセグメント総数（空セグメント含む） |
| 終了状態 | 成功 |

## 分岐の根拠

`fetch_share.py` の `build_transcript_text`: GraphQL レスポンスの `transcripts` 配列は時刻順である保証がないため、`segments.sort(key=lambda x: x[0])` で `startTime` 昇順に整列する。時系列が乱れた transcript.txt は下流（minutes-composer の構造化・minutes-reviewer の時刻ベース突合）の品質に直結するため、レンダリング前のソートが必須。空テキストセグメントは `if not text: continue` でスキップする。

## 関連ケース

- `case-01_success.md`（transcripts が時刻順で返る通常の正常パス）
- `case-05_empty_transcripts.md`（transcripts 自体が空の場合）
- `case-11_null_call_summary.md`（callSummary null との複合条件でも本ケースのソートは同様に機能する）
