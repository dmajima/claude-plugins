# Google Workspace Connector

Google Drive のファイル操作を行うコネクタスキル。

## このドキュメントについて

このファイルは人間向けリファレンスです。Claude の動作では使用されません。

## 導入手順

### 前提

- Claude Code + connector プラグインがインストール済み
- claude.ai の Settings → Integrations → Google Drive を有効化（MCP 経由・推奨）
- API トークン等の事前登録は不要（MCP が認証を自動管理。MCP 未導入時は「MCP 未導入時」セクションを参照）

### 起動方法

「使い方」のトリガーフレーズ / コマンドで自動起動します。

## 使い方

### トリガーフレーズ例

```
Google Drive で報告書を検索して
Google ドキュメントの「プロジェクト計画書」を読んで
Google Drive に新しいスプレッドシートを作成して
最近の Google Drive ファイルを見せて
```

### コマンド

| コマンド | 説明 |
|---------|------|
| `/connector:google-read` | ファイル検索・読取・メタデータ取得 |
| `/connector:google-post` | ファイル作成・コピー |

## MCP 未導入時

MCP ツールが利用できない場合:
1. MCP 導入サポート or 直接対応の選択肢を提示
2. MCP 導入: Google Drive MCP 接続設定を案内
3. 直接対応: Google Drive API v3 + Bearer Token でフォールバック（トークンは credentials.json を照合し、未登録なら対話で確認して「今回のみ利用」または「credentials.json へ保存」を選択できる。credentials-manager プラグインは不要。書き込みはフォールバック非対応）

## ファイル構成

```
skills/google-workspace/
├── SKILL.md                          # スキル定義
├── README.md                         # 人間向けリファレンス（本ファイル）
├── references/
│   └── mcp-tools.md                  # MCP ツール詳細仕様
└── evals/
    ├── case-01_file_search.md         # ファイル検索
    ├── case-02_read_document.md       # ドキュメント読取
    ├── case-03_create_file.md         # ファイル作成（承認フロー）
    ├── case-04_recent_files.md        # 最近のファイル一覧
    ├── case-05_mcp_unavailable.md     # MCP 未導入フォールバック
    ├── case-06_user_cancel_create.md  # 作成中止
    ├── case-07_token_expired.md       # フォールバックトークン失効（401）
    └── case-08_subagent_mcp_unavailable.md # サブエージェント時の mcp_unavailable 返却
```
