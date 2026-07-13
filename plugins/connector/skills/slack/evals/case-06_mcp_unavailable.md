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
- credentials-precheck.md セクション 1 の解決順序で Slack API トークンを確認（credentials-manager（導入時）→ credentials.json の `slack` エントリ直接照合）
- トークンがある場合: `https://slack.com/api/conversations.list` → channel_id 解決 → `conversations.history` で取得
- トークンがない場合: 対話取得フォールバック（credentials-precheck.md セクション 4）の 4 択（入力して続行（今回のみ）/ 入力して続行（保存する）/ 登録手順の案内 / 中止）を提示する（credentials-manager / credentials.json 不在でも停止しない）

### サブエージェント実行時の対比
- サブエージェント（`AskUserQuestion` 利用不可）で MCP 利用不可となった場合は、Phase 2 以降の質問を試みず `{"status":"error","error":"mcp_unavailable","service":"slack",...}` マニフェストを返す（subagent-protocol.md セクション 3.5 で呼び出し元が復帰）

## 分岐根拠

MCP 未導入環境でのフォールバックフロー。MCP 導入サポートと直接 API の二択を提供し、直接 API 選択時も認証情報の解決順序（credentials-precheck.md セクション 1）で必ず対話取得まで到達する。
