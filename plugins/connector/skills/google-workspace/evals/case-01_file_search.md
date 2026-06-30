# case-01: ファイル検索

## 入力

```
Google Drive で「月次報告書」に関するファイルを検索して
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 読み取り（ファイル検索）

### Phase 2: MCP ツール呼び出し
- `mcp__claude_ai_Google_Drive__search_files` を `query: "title contains '月次報告書'"` で呼び出し

### Phase 3: 結果報告
- ファイル名・種別・更新日時・所有者を一覧表示
