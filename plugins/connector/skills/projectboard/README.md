# projectboard スキル

HUE ProjectBoard（Works Applications のプロジェクト管理 SaaS / `*.pm.apps.worksap.com`）の
WBS タスクを操作するスキル。タスクの読み取り・追加・更新と、スケジュールシート全体の構造解析
（WBS ツリー・依存関係・クリティカルパス分析）に対応する。

## このドキュメントについて

本ファイルはスキルの利用者・開発者向けの人間向けリファレンスであり、**Claude のスキル動作では使用しない**。
スキルの実行定義は `SKILL.md` および `references/` 配下を参照のこと。

## 責務（要約）

| 機能 | 内容 |
|------|------|
| タスク読み取り | シート特定 → タスクツリー取得 → 特定タスク参照 / 一覧 CSV 化（標準 10 列 / シート列定義からの全列動的生成） |
| シート構造解析 | WBS ツリー・依存関係（先行 → 後続）・クリティカルパス（CPM: total float）・サマリのレポート生成 |
| タスク追加 | addNode による新規タスク / パッケージ / マイルストーン作成（親・挿入位置指定可） |
| タスク更新 | updateNodeContent によるフィールド単位更新（タイトル・ステータス・進捗・日付・担当者・先行タスク等） |

## 導入手順

### 前提

- bash (Git Bash) / curl / jq / Python 3.9+
- credentials-manager プラグイン（認証情報の管理）

### 事前準備（認証情報）

`~/.claude/credentials.json`（credentials-manager 管理）に `hue-projectboard` エントリを登録する:

```json
{
  "credentials": {
    "hue-projectboard": {
      "type": "password",
      "username": "<ログインメールアドレス>",
      "value": "<パスワード>",
      "auth_method": "form:email:password",
      "domains": ["<tenant>.pm.apps.worksap.com", "pm.apps.worksap.com"]
    }
  }
}
```

## 使い方

### スラッシュコマンド

| コマンド | 操作 |
|---------|------|
| `/connector:projectboard-read <URL or タスク指定>` | タスクの読み取り（読み取り専用） |
| `/connector:projectboard-sheet <URL or シート指定>` | シート全体の構造解析・クリティカルパス（読み取り専用） |
| `/connector:projectboard-post <シート + タスク内容>` | タスクの追加 |
| `/connector:projectboard-update <タスク + 変更内容>` | タスクの更新 |

### 自然言語

- 「ProjectBoard の外部WBS シートのタスクを CSV にして」
- 「https://example-tenant.pm.apps.worksap.com/wbs/project/abcD...//issue/xYzW のクリティカルパスを分析して」
- 「SAMPLE-67 のステータスを実行中に変更して」

## 動作例

入力: 「このシートのスケジュール構造を解析して <シートURL>」

1. credentials.json の `hue-projectboard` を確認 → フォームログイン
2. URL から tenant / urlKey / sheetCode を抽出 → urlKey を UUID に変換
3. シート一覧からシートを特定 → タスクツリー取得（187 タスク等）
4. `analyze_schedule.py` が Markdown レポートを生成:
   - サマリ（type / status 内訳・期間・依存件数・推定総工期）
   - WBS ツリー（階層 + クリティカルノードに ★CP マーク）
   - 依存関係一覧・クリティカルパス（CPM の float=0 経路）
   - 警告（循環依存・duration 単位の自動判定結果等)

書き込み（追加・更新）はユーザー承認（AskUserQuestion）を必ず経由し、実行後にシート再取得で反映を検証する。

## カスタマイズ・拡張

| 変更したい内容 | 触る場所 |
|--------------|---------|
| API エンドポイント・データ構造の変更追従 | `references/api-spec.md`（読み取り）/ `references/api-write.md`（書き込み）— SSOT |
| CSV の列構成 | `scripts/format/tasks_to_csv.py`（--fields / --mode all で動的列） |
| クリティカルパス計算ロジック | `scripts/format/analyze_schedule.py`（duration 推定・CPM） |
| 書き込み API の仕様確定（推定 → 確実） | `references/api-write.md` セクション 8 の手順で HAR 採取 → 同ファイル更新 |

## ファイル構成

```
skills/projectboard/
├── SKILL.md                          # スキル定義（Claude が実行時に読み込む）
├── README.md                         # 本ファイル（人間向け）
├── scripts/
│   ├── setup/
│   │   ├── requirements.txt          # 空（標準ライブラリのみ・依存なし）
│   │   ├── setup_venv.sh             # venv 構築
│   │   ├── teardown_venv.sh          # venv 削除
│   │   └── cleanup_sensitive.sh      # cookies.txt・取得 JSON・HAR の削除
│   ├── auth/
│   │   ├── login.sh                  # フォームログイン（環境変数 PB_TENANT/PB_EMAIL/PB_PASSWORD）
│   │   └── with_session.sh           # GET ラッパ（401 再ログイン + SPA 検知）
│   ├── resolve/
│   │   └── urlkey.py                 # urlKey ⇔ UUID（base62 + round-trip 自己検証）
│   ├── fetch/
│   │   ├── list_sheets.sh            # シート一覧（loadProjectPages）
│   │   ├── sheet_detail.sh           # 列定義・statusSet（getPageDetail）
│   │   └── get_tasks.sh              # タスクツリー（getWbsNodes）
│   ├── write/
│   │   ├── stomp_session.py          # WebSocket+STOMP 接続を保持し書き込みコマンドを実行（標準ライブラリのみ）
│   │   └── post_node_api.sh          # 書き込み POST ラッパ（/wbs/wbs/node・XSRF・401/403・connectionId/operationId 注入）
│   └── format/
│       ├── tasks_to_csv.py           # ツリー → CSV（standard / all モード）
│       └── analyze_schedule.py       # 構造解析 + クリティカルパス（CPM）
├── references/
│   ├── setup.md                      # 環境構築
│   ├── api-spec.md                   # 読み取り API 仕様（SSOT）
│   ├── api-write.md                  # 書き込み API 仕様（SSOT・確証度付き）
│   ├── pitfalls.md                   # 既知の落とし穴 15 項
│   └── procedures.md                 # 実行手順（フロー別コマンド例）
└── evals/                            # 動作期待値ケース + 構造検証スクリプト
```

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `../../references/credentials-precheck.md` | 認証情報の事前確認（プラグイン共通） |
| `../../references/safe-api-access.md` | API アクセス安全原則（プラグイン共通） |
