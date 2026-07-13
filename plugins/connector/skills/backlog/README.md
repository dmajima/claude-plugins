# backlog (skill)

Backlog REST API v2 で課題の検索・取得・コメント取得（読み取り）と、コメント投稿・ステータス等メタ情報更新（書き込み）を行うスキル。書き込みは `render-check` ゲートとユーザー承認を必ず経由する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- 課題検索・課題取得・コメント取得（読み取り系）
- コメント投稿・課題メタ情報更新（ステータス・担当者・優先度・期限等。書き込み系）
- 共有ファイルの一覧取得・メタデータ取得（読み取り系。ファイルダウンロードは対象外）
- プロジェクトの記法設定（textFormattingRule）の取得と `render-check` への引き継ぎ

Azure DevOps の操作は `azure` スキル、レンダリング検証ロジックは `render-check` スキルの担当（本スキルの責務外）。認証情報の恒久保存・一元管理は credentials-manager プラグインが担当しますが **オプション** であり、未導入でも本スキルは credentials.json の直接照合と対話取得フォールバックで動作します。

## 導入手順

### 前提

- Claude Code がインストール済み
- 本スキルが含まれる connector プラグインがインストール済み
- `jq` / `curl` が利用可能であること

### 事前準備（Backlog API キーの登録・任意）

`~/.claude/credentials.json` に対象スペース用のエントリを追加します。API キーは Backlog の個人設定 > API から発行できます。**この事前準備は必須ではありません** — 未登録のまま起動した場合、スキルは API を呼ぶ前に対話（AskUserQuestion）で API キーを確認し、「今回のみ利用」または「credentials.json へ保存」を選択できます。

```json
{
  "credentials": {
    "backlog-apikey": {
      "type": "api_key",
      "value": "<API キー>",
      "urls": ["https://<space>.backlog.jp/*"],
      "domains": ["<space>.backlog.jp"],
      "auth_method": "query:apiKey"
    }
  }
}
```

- エントリ名（`backlog-apikey`）は固定ではありません。スキルは `domains` と対象スペースのホスト名照合でエントリを特定します
- `.backlog.com` スペースの場合は `urls` / `domains` を読み替えてください
- 複数スペースを使う場合はスペースごとにエントリを追加します（別スペースのキーは流用されません）
- エントリがない状態で起動すると、スキルは API を呼ばずに対話で API キーを確認します（サブエージェント経由の呼び出しでは対話できないため `credentials_missing` エラーが返り、呼び出し元が対話取得後に再実行します）

### 起動方法

以下のフレーズで自動起動します:

- 「Backlog で PROJ-123 を取得して」「PROJ-123 の内容とコメントを見せて」
- 「Backlog で『ログイン』に関する課題を検索して」
- 「PROJ-123 にこの調査結果をコメント投稿して」
- 「PROJ-123 のステータスを処理中に変更して」「担当者を山田さんにして」
- 「このファイルリンクの中身を見せて https://example.backlog.jp/file/PROJ/docs/」（ファイル URL）
- 「Backlog の共有ファイルを一覧表示して」

## 使い方（入出力の流れ）

| 操作 | 入力 | 流れ | 出力 |
|-----|------|------|------|
| 読み取り（取得・検索） | 課題キー / プロジェクトキー + キーワード | 認証確認 → API 呼び出し → 整形報告 | 課題情報・コメント・検索結果一覧（課題 URL 付き） |
| 読み取り（ファイル） | ファイル URL（ダイレクトパス or エイリアス） | 認証確認 → URL パース → [エイリアス解決] → API 呼び出し → 整形報告 | ファイル / フォルダ一覧（名前・種別・サイズ・更新日時） |
| 書き込み（投稿・更新） | 課題キー + 本文 / 変更内容 | 認証確認 → 記法判定 → **render-check ゲート** → ID 解決 → **AskUserQuestion 承認** → API 実行 → 結果検証 | 投稿コメント URL / 更新後の値の報告 |

書き込みは render-check 未通過・ユーザー未承認のままでは実行されません（非対話モードでも承認は省略されません）。

## 動作例

### 例 1: 課題取得（読み取り）

ユーザ:
> Backlog で PROJ-123 の内容とコメントを見せて

Claude（要約）:
> credentials.json の認証情報を確認後、`GET /api/v2/issues/PROJ-123` と `GET /api/v2/issues/PROJ-123/comments` を呼び出し、課題キー / 件名 / ステータス / 担当者 / 期限 / 本文要約 / コメント一覧を整形して、課題 URL とともに報告します。

### 例 2: 共有ファイル一覧取得（読み取り）

ユーザ:
> このフォルダの中身を見せて https://example.backlog.jp/file/PROJ/docs/meeting/

Claude（要約）:
> credentials.json の認証情報を確認後、URL からプロジェクトキー `PROJ` とパス `docs/meeting/` を抽出し、`GET /api/v2/projects/PROJ/files/metadata/docs/meeting/` を呼び出します。フォルダ内のファイル・サブフォルダの一覧を名前・種別・サイズ・更新日時の表で報告します。エイリアス URL（`/alias/file/{id}`）の場合は、プロジェクトキーを確認後、download API ヘッダ（ファイル）またはツリー内 ID 検索（フォルダ）でメタデータを取得します。

### 例 3: コメント投稿（書き込み）

ユーザ:
> PROJ-123 にこの調査結果をコメント投稿して

Claude（要約）:
> 認証確認後、`GET /api/v2/projects/PROJ` でプロジェクトの記法設定（Backlog 記法 / Markdown）を判定し、投稿本文を `render-check` スキルで検証します（**必須ゲート**。記法不一致・機密情報等の FAIL があれば修正案を提示し、解消されるまで投稿しません）。検証通過後、投稿先と確定本文を提示して **AskUserQuestion で承認** を得てから `POST /api/v2/issues/PROJ-123/comments` を実行し、コメント URL（`https://<space>.backlog.jp/view/PROJ-123#comment-<id>`）を報告します。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `render-check` | 書き込み前の本文検証ゲートとして本スキルから呼び出される |
| `azure` | Azure DevOps（PR / 作業項目）操作の担当（本スキルの対象外） |

## ファイル構成

```
skills/backlog/
├── SKILL.md                            # スキル定義（Claude が実行時に読み込む）
├── README.md                           # 本ファイル（人間向けリファレンス）
├── references/
│   ├── api-read.md                     # 読み取り API 詳細（検索・取得・ID 解決用一覧）
│   └── api-write.md                    # 書き込み API 詳細（コメント投稿・課題更新）
└── evals/
    ├── README.md                       # ケース一覧と実行確認方法
    ├── case-01_issue_get.md            # 課題取得（読み取り）
    ├── case-02_issue_search.md         # 課題検索（projectId 解決経由）
    ├── case-03_comment_post.md         # コメント投稿（render-check PASS → 承認 → POST）
    ├── case-04_status_update.md        # ステータス変更（ID 解決 → 承認 → PATCH）
    ├── case-05_credentials_missing.md  # 認証情報なし（API を呼ばず対話取得フォールバック）
    ├── case-06_render_check_fail.md    # render-check FAIL → 修正 → 再チェック → 投稿
    ├── case-07_user_cancel_post.md     # 承認で「中止」選択（POST を発行せず終了）
    ├── case-08_http_401_error.md       # HTTP 401（同一キーでリトライせず再取得を確認）
    ├── case-09_delegation_read.md      # 他プラグイン委譲による課題取得（パターン B）
    ├── case-10_file_list.md            # ダイレクトパス URL によるフォルダ内ファイル一覧取得
    ├── case-11_file_alias.md           # エイリアス URL からのファイル情報取得
    ├── case-12_file_direct_path.md     # ダイレクトパス URL によるファイル情報取得
    ├── case-13_folder_alias.md         # エイリアス URL からのフォルダ一覧取得
    ├── case-14_alias_resolve_fail.md   # エイリアス解決失敗（代替情報を依頼）
    ├── case-15_subagent_credentials_missing.md  # サブエージェント時の credentials_missing 返却
    ├── case-16_multi_store_resolution.md  # 複数ストアの優先順位解決
    ├── case-17_subagent_auth_failed.md # サブエージェント時の auth_failed 返却
    └── demo.sh                         # 構造検証スクリプト（外部 API 非依存・読み取り専用）
```

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/api-read.md` | 読み取り API（課題検索 / 取得 / コメント取得 / ステータス・ユーザー・優先度一覧 / 共有ファイル一覧・メタデータ取得） |
| `references/api-write.md` | 書き込み API（コメント投稿 / 課題メタ情報更新）と render-check 連携 |
| `../../references/credentials-precheck.md` | 認証情報の事前確認（プラグイン共通） |
| `../../references/safe-api-access.md` | 外部 API アクセスの安全原則（プラグイン共通） |
| `../../references/rendering/backlog-notation.md` | Backlog 記法のレンダリングルール |
| `../../references/rendering/backlog-markdown.md` | Backlog Markdown のレンダリングルール |
| `evals/` | 動作分岐の期待挙動 |
