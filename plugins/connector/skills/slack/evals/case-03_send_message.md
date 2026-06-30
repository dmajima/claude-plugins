# case-03: メッセージ送信（承認フロー）

## 入力

```
Slack の #general に「明日の MTG は 15:00 からに変更します」と送信して
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 書き込み（メッセージ送信）

### Phase 2: チャンネル ID 解決
- `slack_search_channels` で `query: "general"` を検索
- channel_id を取得

### Phase 3: 承認
- `AskUserQuestion` で送信内容を提示:
  - 送信先: #general (C12345...)
  - 内容: 「明日の MTG は 15:00 からに変更します」
- ユーザーが「送信する」を選択

### Phase 4: 送信実行
- `slack_send_message` を呼び出し
- メッセージリンクを報告

## 分岐根拠

書き込み操作の基本フロー。チャンネル名 → ID 解決 + 承認ゲートを経由。
