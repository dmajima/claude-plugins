# 認証情報の事前確認（共通リファレンス）

connector プラグインの全スキルが外部 API へアクセスする **前に** 実施する認証情報確認の共通手順。確認できない場合は **API リクエストを発行せず、ユーザーへ最初に問い合わせる**。

> **位置付け**: code-review プラグイン（`pr-review` スキルの認証事前確認）と同方式・同一の `~/.claude/credentials.json` を共有する。code-review で TFS 認証（`tfs-password` エントリ）を設定済みの環境では追加設定なしで Azure DevOps 操作が可能。
>
> **目的**: 誤った / 欠落した資格情報で外部 API を叩く事故・無駄なリトライ・401/403 エラー連発を防ぐ。

## 1. サービス別の確認対象

| サービス | 確認対象 | 取得方法 |
|---------|---------|---------|
| Backlog | `~/.claude/credentials.json` の Backlog 用エントリ（`domains` に対象スペースのホストを含み `value` が非空） | `jq` で `domains` 照合 → `value` 非空確認 |
| クラウド Azure DevOps | `az account show`（MS アカウントログイン済みか） / `AZURE_DEVOPS_EXT_PAT` 環境変数 | `az account show` の終了コード |
| オンプレ TFS / Azure DevOps Server | `~/.claude/credentials.json` の `tfs-password` エントリ（`value` + `urls` 必須、`username` または `auth_method=ntlm:<user>` のいずれかでユーザー名取得可能） | `jq -r` で値が空でないか確認 |
| HUE ProjectBoard | `~/.claude/credentials.json` の `hue-projectboard` エントリ（`domains` に対象テナントのホスト `{tenant}.pm.apps.worksap.com` を含み `username` と `value` が非空） | `jq` で `domains` 照合 → `username` / `value` 非空確認 |
| ailead | **認証不要**（外部共有リンクは公開アクセス） | 確認不要。共有リンクの有効期限のみ API 取得後に検証 |
| Slack（MCP 経由） | MCP ツール `mcp__claude_ai_Slack__*` が利用可能であること | MCP ツール呼び出しの成否で判定。利用不可の場合は MCP 導入サポートまたはフォールバック（下記 Slack API エントリ）へ |
| Slack（フォールバック） | `~/.claude/credentials.json` の `slack` エントリ（`domains` に `slack.com` を含み `value` が非空） | `jq` で `domains` 照合 → `value` 非空確認 |
| Google Drive（MCP 経由） | MCP ツール `mcp__claude_ai_Google_Drive__*` が利用可能であること | MCP ツール呼び出しの成否で判定。利用不可の場合は MCP 導入サポートまたはフォールバック（下記 Google Drive API エントリ）へ |
| Google Drive（フォールバック） | `~/.claude/credentials.json` の `google-drive` エントリ（`domains` に `googleapis.com` を含み `value` が非空） | `jq` で `domains` 照合 → `value` 非空確認 |

> credentials-manager プラグイン導入環境では、`credentials-manager` スキル経由での照合を最優先する（グローバルルール `credentials-management.md` 準拠）。本ファイルの手順はその確認結果を connector の操作に適用するためのもの。

## 2. credentials.json のエントリ例

### Backlog（API キー認証）

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

- Backlog REST API v2 の認証は **`?apiKey=<value>` クエリパラメータ** が標準（`auth_method: query:apiKey`）
- `.backlog.com` スペースの場合は `urls` / `domains` を読み替える
- エントリ名は固定しない。`domains` と対象スペースのホスト名照合で特定する

### オンプレ TFS（NTLM 認証）

```json
{
  "credentials": {
    "tfs-password": {
      "type": "password",
      "username": "<your-username>",
      "value": "<password>",
      "urls": ["https://<tfs-host>/*"],
      "domains": ["<tfs-host>"],
      "auth_method": "ntlm:<your-username>"
    }
  }
}
```

### HUE ProjectBoard（フォームログイン認証）

```json
{
  "credentials": {
    "hue-projectboard": {
      "type": "password",
      "username": "<ログインメールアドレス>",
      "value": "<パスワード>",
      "urls": ["https://<tenant>.pm.apps.worksap.com/*"],
      "domains": ["<tenant>.pm.apps.worksap.com", "pm.apps.worksap.com"],
      "auth_method": "form:email:password"
    }
  }
}
```

- Spring Security フォームログイン（`POST /auth/sign-in`、パラメータ名は `username` で値はメールアドレス）
- エントリ名は `hue-projectboard` 固定。対象テナントのホストを `domains` と照合して使用可否を判定する
- MFA / SSO が組織設定で有効な場合はフォームログイン不可（projectboard スキルの login.sh が redirect で検知して明示エラーにする）

### Slack フォールバック（API Token 認証）

```json
{
  "credentials": {
    "slack": {
      "type": "api_key",
      "value": "<xoxb-... or xoxp-...>",
      "urls": ["https://slack.com/api/*"],
      "domains": ["slack.com"],
      "auth_method": "header:Authorization:Bearer"
    }
  }
}
```

- MCP 経由が優先。MCP 利用不可時のフォールバック用

取得コード（実績由来。`username` フィールド未設定のエントリでは `auth_method` の `ntlm:<user>` / `basic:<user>` からユーザー名を抽出する）:

```bash
TFS_USER=$(jq -r '.credentials["tfs-password"].username // empty' "$HOME/.claude/credentials.json")
if [ -z "$TFS_USER" ]; then
  AUTH=$(jq -r '.credentials["tfs-password"].auth_method // empty' "$HOME/.claude/credentials.json")
  case "$AUTH" in (ntlm:*|basic:*) TFS_USER="${AUTH#*:}" ;; esac
fi
TFS_PASS=$(jq -r '.credentials["tfs-password"].value // empty' "$HOME/.claude/credentials.json")
[ -n "$TFS_USER" ] && [ -n "$TFS_PASS" ] || { echo "TFS 認証情報が不足（セクション 3 の案内へ）"; exit 1; }
```

## 3. 確認できない場合の動作

いずれの認証情報も確認できない場合は、API を呼ばずに `AskUserQuestion` で以下を提示する:

```
認証情報が確認できません。以下のいずれかを準備してから再実行してください:

【Backlog】
  - ~/.claude/credentials.json に Backlog 用エントリ（API キー + domains）を追加する
    （API キーは Backlog の個人設定 > API から発行）

【クラウド Azure DevOps】
  - `az login` を実行する
  - または環境変数 `AZURE_DEVOPS_EXT_PAT` を設定する

【オンプレ TFS / Azure DevOps Server】
  - ~/.claude/credentials.json に `tfs-password` エントリを追加する
    （TFS 認証設定済み環境では設定済みの場合あり）

【HUE ProjectBoard】
  - ~/.claude/credentials.json に `hue-projectboard` エントリを追加する
    （type=password / username=ログインメール / value=パスワード /
     auth_method=form:email:password / domains に対象テナントのホスト）

【ailead】
  - 認証不要（外部共有リンクのみ対応）

【Slack】
  - claude.ai の Settings → Integrations → Slack を有効化（MCP 優先）
  - MCP 利用不可の場合: ~/.claude/credentials.json に `slack` エントリを追加する
    （type=api_key / value=xoxb-... or xoxp-... / auth_method=header:Authorization:Bearer）

【Google Drive】
  - claude.ai の Settings → Integrations → Google Drive を有効化（MCP 優先）
  - MCP 利用不可の場合: ~/.claude/credentials.json に `google-drive` エントリを追加する


```

ユーザーが情報を整えるまで API 操作には進まない。

## 4. 部分的な情報のみある場合

| 状態 | 動作 |
|------|------|
| TFS で `username` のみあり `value` がない | パスワードのみユーザーに問い合わせ（その他は再入力させない） |
| TFS で `value` のみあり `username` も `auth_method` も空 | username をユーザーに問い合わせ |
| Backlog でエントリはあるが `domains` に対象スペースが含まれない | 対象スペース用エントリの追加をユーザーに依頼（**別スペースのキーを流用しない**） |
| ProjectBoard でエントリはあるが `domains` に対象テナントが含まれない | 対象テナント用の `domains` 追加をユーザーに依頼（**別テナントへ流用しない**） |
| クラウド ADO で `az` CLI 不在 | インストールを案内し、認証は `az login` をユーザーに促す |
| 「もしかしたら別の保管場所にある」等の推測 | **禁止**。推測で API を呼ぶと誤った資格情報が外部に送信される可能性がある |

## 5. セキュリティ補足

- **値の非表示**: 認証情報の値そのものをユーザーに表示・確認させない（マスク表示 / `value` の存在のみ確認）
- **試行ログ抑制**: 一度 API リクエストを送るとサーバー側ログに認証試行が記録されるため、事前確認で防げる失敗は防ぐ
- **権限の事前検証不能**: 認証ユーザーが対象リソースへの書き込み権限を持つかは API 呼び出し前には判別不能。401/403 受領時点で再認証・権限確認を促す（リトライ禁止、[safe-api-access.md](safe-api-access.md) 参照）
