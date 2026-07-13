# MCP 未導入時のフォールバック

MCP ツール `mcp__claude_ai_Slack__*` が利用不可の場合のフロー。

## Step 1: 選択肢の提示

```
AskUserQuestion({
  question: "Slack MCP ツールが利用できません。どちらの方法で対応しますか？",
  header: "Slack 接続",
  options: [
    {
      label: "MCP を導入する（推奨）",
      description: "Slack MCP を導入して認証接続を確立します。導入後は全操作が利用可能になります。"
    },
    {
      label: "直接対応する",
      description: "Slack Web API を直接使用します。API トークン（xoxb-... / xoxp-...）が必要です（続けて認証情報の確認を行います。未登録の場合は対話で提供できます）。操作は限定的になります。"
    }
  ]
})
```

## Step 2a: MCP 導入を選択した場合

1. Slack MCP の導入手順を案内する:
   - claude.ai にログインし、Settings → Integrations → Slack を有効化
   - または Claude Desktop アプリで Slack 連携を設定
   - Claude Code セッションを再起動
2. 再起動後に MCP ツールが利用可能になったことを確認
3. 元の操作を再開する

## Step 2b: 直接対応を選択した場合

1. [credentials-precheck.md](../../../references/credentials-precheck.md) セクション 1 の解決順序で Slack API トークンを取得する
   - credentials-manager 導入時: credentials-manager スキル経由で照合（オプション）
   - 未導入時: `~/.claude/credentials.json` の `slack` エントリを直接照合（entry key: `slack` / type: `api_key` / `auth_method: header:Authorization:Bearer` / `domains: ["slack.com"]`）
   - どちらでも解決できない場合: 対話取得フォールバック（同セクション 4）でトークン（`xoxb-...` / `xoxp-...`）の提供を受ける（今回のみ利用 / credentials.json への保存を選択可能）
2. Slack Web API (`https://slack.com/api/`) を curl で直接呼び出す
3. 利用可能な操作は以下に限定される:
   - チャンネル一覧: `GET conversations.list`
   - メッセージ取得: `GET conversations.history`
   - メッセージ送信: `POST chat.postMessage`（承認ゲート必須）
4. `safe-api-access.md` の原則に従う（タイムアウト30秒、リダイレクト禁止等）
