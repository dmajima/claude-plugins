# azure (skill)

Azure DevOps（クラウド / オンプレ TFS・Azure DevOps Server）の PR 作成・PR コメント投稿・PR 承認・PR メタ情報更新・作業項目コメント投稿を行うスキル。URL からホスト種別を自動判定し、クラウドは `az` CLI、オンプレ TFS は NTLM（`curl --ntlm`）で操作する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- PR 作成（ソース / ターゲットブランチ・タイトル・説明・レビュアー指定）
- PR コメント投稿（スレッド作成・既存スレッドへの返信）
- PR 承認（vote 設定）・PR メタ情報更新（タイトル・説明・ステータス）
- 作業項目（Work Item）へのコメント投稿
- PR / 作業項目の情報取得（操作前の確認用）
- PR インラインコメント投稿（ファイルパス・行範囲指定付き）
- PR スレッド一覧取得・スレッドステータス変更
- commit 情報取得（コミット詳細・変更ファイル一覧・diff）
- Azure Pipelines 読み取り（ビルド結果・テスト結果・ログの取得）
- 他プラグイン（code-review 等）からの PR 操作委譲の受け入れ

書き込み操作は必ず 2 つのゲートを通過します:

1. **render-check ゲート**（本文を伴う操作）: 投稿本文が投稿先のレンダリング方式で意図どおり表示されるかを `render-check` スキルで検証し、FAIL が解消されるまで投稿しない
2. **ユーザー承認**: 操作内容（対象・操作種別・確定本文）を提示し、AskUserQuestion で承認を得てから API を発行する。承認なしの自動投稿は行わない（非対話モードでも省略しない）

## 導入手順

### 前提

- Claude Code がインストール済み
- connector プラグインがインストール済み

### 事前準備（認証情報）

| 接続先 | 準備 |
|-------|------|
| クラウド Azure DevOps（`dev.azure.com` / `*.visualstudio.com`） | `az` CLI をインストールし `az login` を実行する（または環境変数 `AZURE_DEVOPS_EXT_PAT` を設定する） |
| オンプレ TFS / Azure DevOps Server | `~/.claude/credentials.json` に `tfs-password` エントリ（`username` / `value` / `urls` / `domains` / `auth_method: ntlm:<user>`）を登録する |

`tfs-password` エントリは **code-review プラグイン（pr-review スキル）と同方式・同一ファイルを共有** します。code-review で TFS 認証を設定済みの環境では追加設定は不要です。エントリ例はプラグイン共通の `references/credentials-precheck.md` を参照してください。

`credentials.json` の `domains` に登録されていない TFS ホストへは NTLM 認証情報を送信せず、操作を拒否して登録手順を案内します（SSRF / NTLM リレー対策）。

### 起動方法

以下のフレーズで自動起動します:

- 「feature/x から develop への PR を作成して」
- 「PR !123 に進捗コメントを投稿して」
- 「PR !123 を承認して」
- 「作業項目 #456 に調査結果をコメントして」
- 「PR !123 のタイトルと説明を更新して」

## 動作例

### TFS への PR 作成

ユーザ:
> tfs.example.local の WebApp/webapp リポジトリで feature/login から develop への PR を作成して

Claude（要約）:
> credentials.json の `tfs-password.domains` でホストをオンプレ TFS（api-version 6.0）と判定 → ソース / ターゲットブランチの存在と重複 active PR の有無を確認 → PR 説明を render-check（ターゲット: `ado-markdown`）で検証 → 対象・タイトル・確定説明を提示して AskUserQuestion で承認 → POST 後、作成された PR の URL を報告

### PR 承認（vote）

ユーザ:
> https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123 を承認して

Claude（要約）:
> `dev.azure.com` のためクラウド（az CLI / api-version 7.1）と判定 → 本文なしの書き込みのため render-check は省略 → PR タイトルと vote 値（10 = Approved）を明示して AskUserQuestion で承認 → connectionData API で自分のレビュアー ID を取得 → PUT で vote を設定し、レスポンスの vote=10 を検証して報告

### 作業項目へのコメント投稿（TFS は HTML 変換）

ユーザ:
> 作業項目 #456 に調査結果をコメントして（下書きに Markdown の見出し・コードフェンスを含む）

Claude（要約）:
> TFS の作業項目コメント（`System.History`）は Markdown を解釈しないため、render-check（ターゲット: `ado-workitem-html`）が FAIL → HTML 変換案（`<b>` / `<pre>` / `<br>`）を提示 → 採用後に再チェック PASS → 作業項目タイトルと確定 HTML 本文を提示して承認 → JSON Patch（`System.History` への add）で投稿し、`rev` の増加を検証して報告

クラウド（dev.azure.com）の作業項目コメントは comments API（api-version 7.1-preview.4）で Markdown のまま投稿されます。

## コードレビュー用プラグインとの責務の違い

| 観点 | azure（本スキル） | コードレビュー用プラグイン（pr-review） |
|------|------------------|-----------------------------------|
| 担当 | PR 操作そのもの（作成・コメント投稿・承認・メタ情報更新・作業項目コメント） | PR の観点別コードレビュー・指摘コメントの組み立てと投稿 |
| 投稿する本文 | ユーザーが指定した本文 | レビューエージェントが組み立てた指摘 |
| 認証情報 | `~/.claude/credentials.json` の `tfs-password` / `az login`（共通） | 同左（同一エントリを共有） |

「PR をレビューして指摘して」は pr-review、「PR を作って / コメントして / 承認して」は本スキルが担当します。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `render-check` | 書き込み前の必須ゲート（本スキルが内部で呼び出す） |
| `backlog` | Backlog の課題操作（本スキルの責務外） |
| code-review プラグイン `pr-review` | PR の観点別レビュー（本スキルの責務外。TFS 認証情報を共有） |
| credentials-manager プラグイン | 認証情報の保存・管理 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/host-detection.md` | ホスト種別判定（クラウド / TFS / 操作不可）と URL 解析 |
| `references/pr-operations.md` | PR 操作 API 詳細（取得・作成・コメント・vote・メタ更新） |
| `references/workitem-operations.md` | 作業項目操作 API 詳細（取得・コメント投稿） |
| `../../references/credentials-precheck.md` | 認証事前確認（プラグイン共通） |
| `../../references/safe-api-access.md` | API アクセス安全原則（プラグイン共通） |
| `../../references/rendering/azure-devops-markdown.md` | Azure DevOps レンダリングルール（プラグイン共通） |
| `evals/` | 動作分岐の期待挙動 |

## ファイル構成

```
skills/azure/
├── SKILL.md                            # スキル定義（Claude が実行時に読み込む）
├── README.md                           # 本ファイル（人間向け。Claude 動作では不使用）
├── references/
│   ├── host-detection.md               # ホスト判定・URL 解析
│   ├── pr-operations.md                # PR 操作 API 詳細
│   └── workitem-operations.md          # 作業項目操作 API 詳細
└── evals/
    ├── README.md                       # ケース一覧と実行確認方法
    ├── case-01_pr_create_tfs.md        # TFS への PR 作成
    ├── case-02_pr_comment_cloud.md     # クラウド PR へのコメント投稿
    ├── case-03_pr_approve.md           # PR 承認（vote=10）
    ├── case-04_workitem_comment_tfs.md # TFS 作業項目コメント（HTML 変換）
    ├── case-05_unregistered_host.md    # 未登録ホストの拒否
    ├── case-06_user_cancel_write.md    # 承認で「キャンセル」選択（threads API を発行せず終了）
    └── demo.sh                         # 構造検証（外部 API 不使用・読み取り専用）
```
