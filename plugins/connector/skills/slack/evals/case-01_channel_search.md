# case-01: チャンネル検索

## 入力

```
Slack で engineering に関するチャンネルを検索して
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 読み取り（チャンネル検索）

### Phase 2: MCP ツール呼び出し
- `mcp__claude_ai_Slack__slack_search_channels` を `query: "engineering"` で呼び出し

### Phase 3: 結果報告
- チャンネル名・ID・トピック・説明・アーカイブ状態を一覧表示

## 分岐根拠

最も基本的な読み取り操作。ID 解決が不要なケース。
