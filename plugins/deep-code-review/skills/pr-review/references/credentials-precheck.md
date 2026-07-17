# Step 1.5: 認証情報の事前確認（詳細実装）

`pr-review` スキル Step 1.5 の詳細実装。ホスト判定（Step 1）の結果に応じた認証情報が利用可能かを PR API への **アクセスを試みる前に** 確認する。確認できない場合は **API リクエストを発行せず、ユーザーへ最初に問い合わせ** る。

> **位置付け**: 旧 SKILL.md Step 0 系から分離した SSOT。SKILL.md 本体には目的・要点のみ残し、確認手順表・部分情報時の挙動・セキュリティ補足は本ファイルに集約する（章番号は「Step 1.5」でフロー図と論理順序を一致させている）。

> **目的**: 誤った/欠落した資格情報で外部 API を叩く事故・無駄なリトライ・401/403 エラー連発を防ぐ。

> **認証情報取得の委譲モデル（U12）**: 外部接続の認証情報取得は **`connector` プラグインに委譲**する。connector が **credentials-manager プラグインの認証情報ストア**（`.claude/.local/plugins/credentials-manager/credentials.json`。リポジトリ優先 → ホーム。後方互換で従来パス `~/.claude/credentials.json` も参照）を含む複数ソース（gh / az CLI・環境変数等）から解決する。**connector に接続していれば、deep-code-review は credentials-manager を直接依存・直接呼び出しせず、`credentials.json` も自前で直接参照しない**（本ファイル 1.5.1 の確認も connector に委譲する）。認証情報の **登録・保存** はユーザーが credentials-manager プラグイン経由で行う（それが「credentials-manager 連携前提」の実体）。

---

## 1.5.1 確認手順

### ホスト別の確認対象

ホスト判定（SKILL.md Step 1）の結果に応じて、必要な情報を以下から確認する。

| ホスト | 確認対象 | 取得方法 | 備考 |
|--------|---------|---------|------|
| GitHub | `connector:github` に読み取り操作を委譲し、認証確認は connector 側で実施 | connector が `gh auth status` 等を実行 | pr-review からの直接 `gh` 実行は行わない |
| クラウド Azure DevOps | `connector:azure` に読み取り操作を委譲し、認証確認は connector 側で実施 | connector が `az account show` 等を実行 | pr-review からの直接 `az` 実行は行わない |
| オンプレ TFS Server | `connector:azure` に読み取り操作を委譲し、認証確認は connector 側で実施 | connector が credentials.json を参照 | pr-review からの直接 credentials.json 参照は行わない |

### 確認できない場合の動作

いずれの認証情報も確認できない場合は、API を呼ばずに `AskUserQuestion` で以下を提示する:

```
認証情報が確認できません。

まず PR の URL からあなたのケースを特定してください:
  - URL が `github.com` を含む                       → 【GitHub】の手順
  - URL が `dev.azure.com` または `*.visualstudio.com` → 【クラウド Azure DevOps】の手順
  - URL が社内ホスト（例: `tfs.example.com` 等の独自ドメイン） → 【オンプレ TFS Server】の手順

該当する 1 つだけを準備してから再実行してください:

【GitHub】
  - `gh auth login` を実行する
  - または環境変数 `GH_TOKEN` を設定する

【クラウド Azure DevOps】
  - `az login` を実行する
  - または環境変数 `AZURE_DEVOPS_EXT_PAT` を設定する

【オンプレ TFS Server】
  - credentials-manager プラグインで `tfs-password` エントリを登録する（connector が
    credentials-manager の標準ストア `.claude/.local/plugins/credentials-manager/credentials.json`
    を参照する。後方互換で従来パス `~/.claude/credentials.json` も可）。登録内容:
    {
      "type": "password",
      "username": "<your-username>",
      "value": "<password>",
      "urls": ["https://<tfs-host>/*"],
      "domains": ["<tfs-host>"],
      "auth_method": "ntlm:<your-username>"
    }
```

ユーザーが情報を整えるまで Step 1 以降には進まない。

---

## 1.5.2 部分的な情報のみある場合

| 状態 | 動作 |
|------|------|
| TFS で `username` のみあり `value` がない | **パスワードのみユーザーに問い合わせ**（その他の情報は再入力させない） |
| TFS で `value` のみあり `username` も `auth_method` も空 | username をユーザーに問い合わせ（または `auth_method=ntlm:<user>` 形式での再登録を促す） |
| GitHub で `gh` 不在 | `env-setup` スキルでインストールしつつ、認証は `gh auth login` をユーザーに促す |
| Cloud ADO で `az` 不在 | `env-setup` スキルでインストールしつつ、認証は `az login` をユーザーに促す |
| 「もしかしたら別の保管場所にある」等の推測 | **禁止**。推測で API を呼ぶと誤った資格情報が外部に送信される可能性があるため |

---

## 1.5.3 セキュリティ補足

- **値の非表示**: 認証情報の **値そのもの** をユーザーに表示・確認させない（マスクする / `value` の存在のみ確認）
- **権限の事前検証不能**: 他者が起票した PR のレビュー時、認証ユーザーがその PR にコメント権限を持っているかは API 呼び出し前には判別不能。401/403 を受領した時点で再認証を促す
- **試行ログ抑制**: 一度 API リクエストを送るとサーバー側ログに認証試行が記録されるため、**事前確認で防げる失敗は防ぐ**

---

## 関連リファレンス

- `azure-devops-tfs-ntlm.md` セクション 1 — TFS NTLM 認証の credentials.json 設定詳細
- `azure-devops-cloud.md` — クラウド ADO の `az login` / PAT 認証
- `github.md` — GitHub の `gh auth` / `GH_TOKEN`
