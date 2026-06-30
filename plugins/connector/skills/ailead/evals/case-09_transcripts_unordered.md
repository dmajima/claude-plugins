# case-09: transcripts が時刻順でないレスポンス

## 入力

```
ailead の共有リンクからデータを取得して
https://dashboard.ailead.app/share/<有効な share-key>
```

## 前提条件

- 共有リンクが有効（期限内）
- GraphQL 呼び出しは成功するが、レスポンスの `externalShare.transcripts` 配列が時刻順でない
  - 例: `startTime` が 0.5 → 0.9 → 0.0 → 0.2 の順
- 空テキスト（`text` が空文字・空白のみ・null）のセグメントが混在していてもよい

## 期待される動作

### Phase 1-2: URL 確認・作業領域準備
- 通常通り実行

### Phase 3: データ取得
- `fetch_share.py` を venv の Python で実行
- `build_transcript_text` が以下を行う:
  1. 空テキストのセグメントをスキップ（`if not text: continue`）
  2. `startTime * duration` で実秒数を算出
  3. **`startTime` 昇順にソート**してから各行を出力（`segments.sort(key=lambda x: x[0])`）
- 4 ファイルすべてが正常に出力され、exit 0 で終了

### Phase 4: 結果報告
- 通常通り報告

### Phase 5: クリーンアップ
- venv 削除

## 期待される出力

| ファイル | 期待値 |
|---------|-------|
| `workspace/transcript.txt` | 1 行目のタイムスタンプが最小、末行が最大（全行が時刻昇順）。空テキストセグメントの行が存在しない |
| `workspace/metadata.json` | `transcriptCount` はレスポンスのセグメント総数（空セグメント含む） |
| 終了状態 | 成功 |

## 分岐根拠

`fetch_share.py` の `build_transcript_text`: GraphQL レスポンスの `transcripts` 配列は時刻順である保証がないため、`segments.sort(key=lambda x: x[0])` で `startTime` 昇順に整列する。時系列が乱れた transcript.txt は下流（議事録の構造化・時刻ベース突合）の品質に直結するため、レンダリング前のソートが必須。空テキストセグメントは `if not text: continue` でスキップする。

## 関連ケース

- `case-01_share_fetch_success.md`（transcripts が時刻順で返る通常の正常パス）
- `case-05_empty_transcript.md`（transcripts 自体が空の場合）
- `case-08_null_call_summary.md`（callSummary null との複合条件でも本ケースのソートは同様に機能する）
