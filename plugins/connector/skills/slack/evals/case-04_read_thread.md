# case-04: スレッド読取

## 入力

```
Slack の #dev-ops チャンネルで最新のメッセージのスレッドを読みたい
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 読み取り（スレッド読取）

### Phase 2: チャンネル ID 解決 + メッセージ取得
- `slack_search_channels` で `query: "dev-ops"` → channel_id
- `slack_read_channel` で `channel_id, limit: 5` → 最新メッセージ一覧

### Phase 3: スレッド読取
- 最新メッセージの `message_ts` を使用
- `slack_read_thread` で `channel_id, message_ts` → スレッド内容

### Phase 4: 結果報告
- スレッドの全返信を時系列で報告

## 分岐根拠

多段の MCP 呼び出し（チャンネル検索 → メッセージ取得 → スレッド取得）が必要なケース。
