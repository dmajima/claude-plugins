# MCP 未導入時のフォールバック

MCP ツール `mcp__claude_ai_Google_Drive__*` が利用不可の場合のフロー。

## Step 1: 選択肢の提示

```
AskUserQuestion({
  question: "Google Drive MCP ツールが利用できません。どちらの方法で対応しますか？",
  header: "Google 接続",
  options: [
    {
      label: "MCP を導入する（推奨）",
      description: "Google Drive MCP を導入して認証接続を確立します。導入後は全操作が利用可能になります。"
    },
    {
      label: "直接対応する",
      description: "Google Drive API を直接使用します。OAuth2 Bearer Token が必要です（続けて認証情報の確認を行います。未登録の場合は対話で提供できます）。操作は限定的になります。"
    }
  ]
})
```

## Step 2a: MCP 導入を選択した場合

1. Google Drive MCP の導入手順を案内する:
   - claude.ai にログインし、Settings → Integrations → Google Drive を有効化
   - Google アカウントで認証を完了
   - Claude Code セッションを再起動
2. 再起動後に MCP ツールが利用可能になったことを確認
3. 元の操作を再開する

## Step 2b: 直接対応を選択した場合

1. [credentials-precheck.md](../../../references/credentials-precheck.md) セクション 1 の解決順序で Google API トークンを取得する
   - credentials-manager 導入時: credentials-manager スキル経由で照合（オプション）
   - 未導入時: `~/.claude/credentials.json` の `google-drive` エントリを直接照合（entry key: `google-drive` / type: `api_key` / `auth_method: header:Authorization:Bearer` / `domains: ["googleapis.com"]`）
   - どちらでも解決できない場合: 対話取得フォールバック（同セクション 4）で OAuth2 Bearer トークンの提供を受ける（今回のみ利用 / credentials.json への保存を選択可能）
2. Google Drive API v3 (`https://www.googleapis.com/drive/v3/`) を curl で直接呼び出す
3. 利用可能な操作は以下に限定される:
   - ファイル検索: `GET files?q=...`
   - メタデータ取得: `GET files/{fileId}`
   - ファイル読取: `GET files/{fileId}?alt=media` または `GET files/{fileId}/export?mimeType=...`
4. `safe-api-access.md` の原則に従う
5. 書き込み操作（ファイル作成・コピー）はフォールバックでは対応不可。MCP 導入を推奨する
