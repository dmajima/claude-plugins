# case-04: 最近のファイル一覧

## 入力

```
Google Drive の最近更新されたファイルを5件見せて
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 読み取り（最近のファイル一覧）

### Phase 2: MCP ツール呼び出し
- `list_recent_files` で `orderBy: "lastModified"`, `pageSize: 5` を指定

### Phase 3: 結果報告
- ファイル名・種別・最終更新日時を一覧表示
