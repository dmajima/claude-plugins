# case-05: 文字起こし未完了

## 入力

```
https://dashboard.ailead.app/share/processing_key のデータを取得して
```

## 前提条件

- 共有リンクは有効
- GraphQL レスポンスは返るが `transcripts` が空配列
- `callTasks` の `TRANSCRIPT` ステータスが `PROCESSING`

## 期待される動作

### Phase 1-2: URL確認・準備
- 正常系と同様

### Phase 3: データ取得
- `fetch_share.py` が正常にデータ取得
- `transcript.txt` は空文字列
- `metadata.json` の `transcriptCount` が 0
- スクリプトの WARNING 出力: "文字起こしセグメントが0件です"

### Phase 4: 結果報告
- 会議メタデータは正常に報告
- **「文字起こしが未完了です」** とユーザーに警告
- 「しばらく待ってから再取得してください」と案内

## 分岐根拠

録画直後など、ailead 側の処理が未完了の場合。データは部分的に取得可能。
