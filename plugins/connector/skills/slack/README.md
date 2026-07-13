# Slack Connector

Slack ワークスペースの情報取得・メッセージ送信・Canvas操作を行うコネクタスキル。

## このドキュメントについて

このファイルは人間向けリファレンスです。Claude の動作では使用されません。

## 導入手順

### 前提

- Claude Code + connector プラグインがインストール済み
- claude.ai の Settings → Integrations → Slack を有効化（MCP 経由・推奨）
- API トークン等の事前登録は不要（MCP が認証を自動管理。MCP 未導入時は「MCP 未導入時」セクションを参照）

### 起動方法

「使い方」のトリガーフレーズ / コマンドで自動起動します。

## 使い方

### トリガーフレーズ例

```
Slack で engineering に関するチャンネルを検索して
Slack の #general の最新メッセージを見せて
Slack の #dev に「デプロイ完了」と送信して
```

### コマンド

| コマンド | 説明 |
|---------|------|
| `/connector:slack-read` | チャンネル・メッセージ・ユーザーの検索・読取 |
| `/connector:slack-post` | メッセージ送信・リアクション・Canvas操作 |

## 動作例

### メッセージ検索

入力: `Slack で先週のデプロイに関するメッセージを検索して`

→ MCP ツール `slack_search_public` を呼び出し、結果を整形して報告

### メッセージ送信

入力: `Slack の #general に「MTGは15時から」と送信して`

1. チャンネル名 → channel_id 解決
2. 送信内容の承認確認（AskUserQuestion）
3. 承認後に送信実行
4. メッセージリンクを報告

## MCP 未導入時

MCP ツールが利用できない場合:
1. MCP 導入サポート or 直接対応の選択肢を提示
2. MCP 導入: Slack MCP 接続設定を案内
3. 直接対応: Slack Web API + API トークンでフォールバック（トークンは credentials.json を照合し、未登録なら対話で確認して「今回のみ利用」または「credentials.json へ保存」を選択できる。credentials-manager プラグインは不要）

## ファイル構成

```
skills/slack/
├── SKILL.md                              # スキル定義
├── README.md                             # 人間向けリファレンス（本ファイル）
├── references/
│   └── mcp-tools.md                      # MCP ツール詳細仕様
└── evals/
    ├── case-01_channel_search.md          # チャンネル検索
    ├── case-02_message_search.md          # メッセージ検索
    ├── case-03_send_message.md            # メッセージ送信（承認フロー）
    ├── case-04_read_thread.md             # スレッド読取
    ├── case-05_user_cancel_send.md        # 送信中止
    ├── case-06_mcp_unavailable.md         # MCP 未導入フォールバック
    ├── case-07_private_search_consent.md  # プライベート検索の同意確認
    ├── case-08_non_interactive_write.md   # 非対話モードの書き込み
    ├── case-09_token_expired.md           # フォールバックトークン失効（401）
    └── case-10_subagent_mcp_unavailable.md # サブエージェント時の mcp_unavailable 返却
```
