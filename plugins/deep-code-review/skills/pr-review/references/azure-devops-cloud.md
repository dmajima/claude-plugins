# Azure DevOps PR 操作 — クラウド (dev.azure.com / visualstudio.com)

> **本ファイルは connector:azure の内部実装リファレンス（デバッグ・トラブルシューティング用）として維持する。pr-review からの直接 API 実行は廃止され、すべて `connector:azure` 経由で操作する。** pr-review の投稿フローは `comment-posting.md` セクション 7.2 を参照。

`pr-review` スキルが **クラウド Azure DevOps**（`dev.azure.com` / `*.visualstudio.com`）の PR を扱う際のコマンド・REST API 詳細。

> **位置付け**: 旧 `azure-devops.md` の 2.x セクションから分離。オンプレ TFS は `azure-devops-tfs-ntlm.md`、共通仕様は `azure-devops-common.md` を参照。

> **方針**: 一般メンバーが PAT を発行する負担を避けるため、**MS アカウント（Microsoft Entra ID / Azure AD）による `az login`** を最優先とする。Azure DevOps の組織にアクセス権限を持つ MS アカウントがあれば、本プラグインの大半の操作（`az repos pr` / `az devops invoke` / `az rest`）は PAT なしで実行できる。

---

## 1. 認証（`az login`）

```bash
# ブラウザで MS アカウントにサインイン
az login

# ブラウザが使えない環境（SSH・リモート等）
az login --use-device-code

# 認証確認
az account show

# 組織・プロジェクト既定値の設定（任意）
az devops configure --defaults organization=https://dev.azure.com/<org>
az devops configure --defaults project=<project>
```

**MS アカウントで動作する操作:**

| 操作 | コマンド例 | 動作 |
|------|----------|:---:|
| PR 一覧・詳細取得 | `az repos pr list` / `az repos pr show` | ✅ |
| PR コメント追加 | `az devops invoke --area git --resource pullRequestThreads` | ✅ |
| スレッド一覧・ステータス更新 | `az devops invoke` / `az rest` | ✅ |
| Azure DevOps REST API 全般 | `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url ...` | ✅ |

`az` CLI のトークンは OS の安全な保管領域（Windows: DPAPI、macOS: Keychain、Linux: Secret Service）に保存される。期限切れ時は自動再認証される。

> 補助: PAT を使う場合は環境変数 `AZURE_DEVOPS_EXT_PAT` 経由（`az` 拡張が自動で拾う）。`setx` での永続化や `-u :$PAT` のコマンドライン引数渡しは **禁止**。

---

## 2. PR 一覧取得

```bash
az repos pr list \
  --org https://dev.azure.com/<org> \
  --project <project> \
  --repository <repo> \
  --status active \
  --output json
```

または `az devops invoke` 経由（より細かい制御が可能）:

```bash
az devops invoke --area git --resource pullRequests \
  --route-parameters project=<project> \
  --query-parameters 'searchCriteria.status=active' \
  --org https://dev.azure.com/<org> --api-version 7.1
```

---

## 3. PR メタ情報・差分

```bash
# PR 詳細
az repos pr show --id <N> --org https://dev.azure.com/<org>

# 差分は git で取得（Azure DevOps は GitHub の refs/pull/<N>/merge を提供しない）
git fetch origin <sourceRefName>:<sourceBranch>
git fetch origin <targetRefName>:<targetBranch>
git diff <targetBranch>...<sourceBranch>
```

---

## 4. スレッド一覧・ステータス更新

```bash
# スレッド一覧
az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<N> \
  --org https://dev.azure.com/<org> --api-version 7.1

# スレッドステータス更新（fixed に変更）
# threadId は数値のみ受け付け：[[ "$threadId" =~ ^[0-9]+$ ]] で検証必須
BODY=$(mktemp); chmod 600 "$BODY"
# Cloud 経路は NETRC を使わないため `cleanup_secrets` 関数化は不要（BODY のみ）。
# 将来 RESP / CONTENT_FILE 等の一時ファイルを追加する場合は、
# azure-devops-tfs-ntlm.md セクション 2 の cleanup_secrets パターン
# （5 変数管理 + 先張り trap）への統一を検討すること。
trap 'rm -f "${BODY:-}" 2>/dev/null || true' EXIT INT TERM HUP QUIT
jq -n '{status: "fixed"}' > "$BODY"

az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<N> threadId=<threadId> \
  --org https://dev.azure.com/<org> --api-version 7.1 \
  --http-method PATCH --in-file "$BODY"
```

---

## 5. インラインコメント追加（範囲指定スレッド）

> **コマンドインジェクション対策**: コメント本文・ファイルパス等のユーザー入力由来の値は **必ず `jq --arg` / `--argjson`** 経由で渡す。

```bash
BODY=$(mktemp); chmod 600 "$BODY"
# Cloud 経路は NETRC を使わないため `cleanup_secrets` 関数化は不要（BODY のみ）。
# 将来 RESP / CONTENT_FILE 等の一時ファイルを追加する場合は、
# azure-devops-tfs-ntlm.md セクション 2 の cleanup_secrets パターン
# （5 変数管理 + 先張り trap）への統一を検討すること。
trap 'rm -f "${BODY:-}" 2>/dev/null || true' EXIT INT TERM HUP QUIT
jq -n \
  --arg content "<コメント本文>" \
  --arg path "/<ファイルパス>" \
  --argjson start_line <開始行> \
  --argjson end_line <終了行> \
  '{
    comments: [{ parentCommentId: 0, content: $content, commentType: 1 }],
    status: "active",
    threadContext: {
      filePath: $path,
      rightFileStart: { line: $start_line, offset: 1 },
      rightFileEnd:   { line: $end_line, offset: 1 }
    }
  }' > "$BODY"

az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<N> \
  --org https://dev.azure.com/<org> --api-version 7.1 \
  --http-method POST --in-file "$BODY"
```

---

## 6. 自著判定（クラウド MS アカウント認証時）

クラウド ADO は `uniqueName` が **UPN 形式（`user@example.com`）固定**。`az account show --query user.name -o tsv` の値と比較。**詳細実装は `${CLAUDE_SKILL_DIR}/references/author-identity.md` セクション 3 を参照**。

> ⚠️ **`displayName` での比較は禁止**。常に `uniqueName`（UPN）または `id`（GUID）を使う。空文字ガードを **必ず** 入れる。

---

## 7. 禁止事項（クラウド向け）

- ❌ **`setx AZURE_DEVOPS_EXT_PAT <PAT>`（Windows レジストリ平文永続化）**
- ❌ **`curl -u :$PAT` のコマンドライン引数経由 PAT 渡し**（`ps` / EDR から漏洩）
- ❌ PAT を平文ファイル（`token.txt` 等）にコミット
- ❌ パスワード・PAT をチャット欄に平文で貼る
- ❌ 自著判定で `displayName` を使う（必ず `uniqueName` または `id`）

---

## 関連リファレンス

- `azure-devops-tfs-ntlm.md` — オンプレ TFS Server (NTLM 認証)
- `azure-devops-common.md` — 共通仕様（status 値・commentType・URL 解析・レート制限）
- `author-identity.md` — 自著判定の詳細実装
