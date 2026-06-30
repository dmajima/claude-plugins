# case-06: MCP ツール利用不可 — フォールバック選択

## 入力

```
Slack の #general を読みたい
```

## 前提条件

- MCP ツール `mcp__claude_ai_Slack__*` が利用不可（未接続・セッション切れ・未導入等）

## 期待される動作

### Phase 1: MCP 利用可否確認
- MCP ツール呼び出しがエラーを返す、または MCP ツールが存在しない

### Phase 2: 選択肢の提示
- `AskUserQuestion` でフォールバック選択を提示:
  - **MCP を導入する（推奨）**: Slack MCP 導入手順を案内
  - **直接対応する**: Slack Web API を直接使用

### Phase 3a: MCP 導入を選択した場合
- Slack MCP の導入手順を案内:
  1. claude.ai の Settings → Integrations → Slack を有効化
  2. Claude Code セッションを再起動
- 再起動後、元の操作（#general の読取）を再開する手順を提示

### Phase 3b: 直接対応を選択した場合
- `credentials-manager` スキルで Slack API トークンの有無を確認
- トークンがある場合: `https://slack.com/api/conversations.list` → channel_id 解決 → `conversations.history` で取得
- トークンがない場合: ユーザーに API トークンの提供を依頼

## 分岐根拠

MCP 未導入環境でのフォールバックフロー。MCP 導入サポートと直接 API の二択を提供。
