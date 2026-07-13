# case-10: サブエージェント呼び出しで MCP 利用不可（mcp_unavailable マニフェスト返却）

## 入力

他プラグインが subagent-protocol.md のテンプレートに従い `Agent()` で起動。args: `読み取りのみ。チャンネル #general の最新メッセージを取得して` + 出力ディレクトリ + マニフェスト返却指示

## 前提条件

- サブエージェント実行環境で MCP ツール `mcp__claude_ai_Slack__*` が利用不可
- credentials.json に `slack` エントリなし（フォールバックトークンも未解決）

## 期待される動作

1. サブエージェント内で `Skill(skill: "connector:slack")` を実行する
2. MCP ツールが利用不可と判定する
3. サブエージェント実行（`AskUserQuestion` 利用不可）のため、mcp-fallback.md の選択肢提示・対話取得を試みない（credentials-precheck.md セクション 5）
4. API を呼ばず、以下のエラーマニフェストのみを返して終了する:

```json
{
  "status": "error",
  "error": "mcp_unavailable",
  "service": "slack",
  "detail": "MCP ツール mcp__claude_ai_Slack__* が利用不可・credentials.json に slack エントリなし"
}
```

5. 呼び出し元は subagent-protocol.md セクション 3.5 に従い、メインコンテキストで mcp-fallback.md（MCP 導入案内 / 直接対応 + 対話取得）を実施してから再起動する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（messages.json は書き出されない） |
| 返却値 | JSON マニフェスト（`status=error` / `error=mcp_unavailable` / `service=slack`） |
| 終了状態 | 呼び出し元が復帰手順を実行可能 |

## 分岐根拠

サブエージェント実行時は対話（MCP フォールバック選択・トークンの対話取得）が実行できないため、エラーマニフェスト返却（credentials-precheck.md セクション 1 の 3b / subagent-protocol.md セクション 3.3）に分岐する。

## 関連ケース

- `case-06_mcp_unavailable.md`（同じ MCP 不可でもメインコンテキストでは選択肢提示に進む対比）
