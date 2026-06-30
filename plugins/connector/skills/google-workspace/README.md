# Google Workspace Connector

Google Drive のファイル操作を行うコネクタスキル。

## このドキュメントについて

このファイルは人間向けリファレンスです。Claude の動作では使用されません。

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
3. 直接対応: Google Drive API v3 + Bearer Token でフォールバック

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
    └── case-06_user_cancel_create.md  # 作成キャンセル
```
