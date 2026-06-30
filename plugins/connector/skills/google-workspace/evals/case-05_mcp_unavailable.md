# case-05: MCP ツール利用不可 — フォールバック選択

## 入力

```
Google Drive でファイルを検索したい
```

## 前提条件

- MCP ツール `mcp__claude_ai_Google_Drive__*` が利用不可

## 期待される動作

### Phase 1: MCP 利用可否確認
- MCP ツール呼び出しがエラーを返す、または MCP ツールが存在しない

### Phase 2: 選択肢の提示
- `AskUserQuestion` でフォールバック選択を提示:
  - **MCP を導入する（推奨）**: Google Drive MCP 導入手順を案内
  - **直接対応する**: Google Drive API を直接使用

### Phase 3a: MCP 導入を選択した場合
- Google Drive MCP の導入手順を案内:
  1. claude.ai の Settings → Integrations → Google Drive を有効化
  2. Google アカウントで認証
  3. Claude Code セッションを再起動

### Phase 3b: 直接対応を選択した場合
- `credentials-manager` スキルで Google API トークンの有無を確認
- トークンがある場合: `https://www.googleapis.com/drive/v3/files?q=...` で検索
- トークンがない場合: ユーザーに Bearer Token の提供を依頼
