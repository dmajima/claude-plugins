# case-02: ドキュメント読取

## 入力

```
Google Drive の「プロジェクト計画書」の内容を読みたい
```

## 期待される動作

### Phase 1: ファイル名 → fileId 解決
- `search_files` で `query: "title = 'プロジェクト計画書'"` → fileId 取得
- 複数候補がある場合は `AskUserQuestion` で選択

### Phase 2: 内容読取
- `read_file_content` で `fileId` を指定して内容取得

### Phase 3: 結果報告
- ドキュメント内容を整形して報告
