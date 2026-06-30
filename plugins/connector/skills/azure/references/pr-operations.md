# PR 操作 API（詳細実装）

`azure` スキルの PR 操作（取得・作成・コメント投稿・承認・メタ情報更新）の詳細実装。書き込み操作の **実行前提**: render-check 通過（本文を伴う操作）+ `AskUserQuestion` でのユーザー承認済みであること。

共通の安全原則（NETRC パターン・一時ファイル管理・jq --arg による body 構築・HTTP エラー分岐）は [safe-api-access.md](../../../references/safe-api-access.md) に従う。TFS の REST 呼び出しは全て以下の形を基本とする:

```bash
# NETRC / BODY / RESP は mktemp + chmod 600 + 先張り trap で管理（safe-api-access.md セクション 3）
HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -X <METHOD> --data-binary @"$BODY" \
  -o "$RESP" -w '%{http_code}' \
  "{base}/{project}/_apis/git/repositories/{repo}/<RESOURCE>?api-version=6.0" || echo "000")
```

body は必ず `--data-binary` で送る（`-d` は改行を削除する。safe-api-access.md セクション 4）。本パターンは PR 作成・スレッド投稿・status 更新の実運用実績（HTTP 200 / 201）に基づく。

## 1. PR 情報取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az repos pr show --id {prId} --org {base} --output json` |
| TFS | `GET {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}?api-version=6.0` |

- 主要フィールド: `pullRequestId` / `title` / `description` / `status`（active / completed / abandoned）/ `sourceRefName` / `targetRefName` / `createdBy.displayName` / `reviewers[]`（`vote` 含む）

## 2. PR 作成

### 事前確認（必須）

1. ソース / ターゲットブランチの存在確認: `git ls-remote --heads origin {branch}` または refs API
2. 同一ソース → ターゲットの active PR が既に存在しないか（PR 一覧 `searchCriteria.sourceRefName` で確認。存在する場合は重複作成せずユーザーに提示）
3. `description` は render-check（ターゲット: `ado-markdown`）を通過していること

### 実行

| 種別 | 方法 |
|-----|------|
| クラウド | `az repos pr create --org {base} --project {project} --repository {repo} --source-branch {src} --target-branch {tgt} --title "..." --description "..."`（下書きは `--draft`） |
| TFS | `POST {base}/{project}/_apis/git/repositories/{repo}/pullrequests?api-version=6.0` |

TFS の body（`jq -n` で構築。日本語を含むタイトル・説明は `--rawfile` でファイル渡し。`--arg` に日本語を渡すと Windows の jq.exe が CP932 解釈して文字化けする — safe-api-access.md セクション 4）:

```bash
TITLE_FILE=$(mktemp); chmod 600 "$TITLE_FILE"; printf '%s' "$PR_TITLE" > "$TITLE_FILE"
jq -n --arg src "refs/heads/feature/x" --arg tgt "refs/heads/develop" \
      --rawfile title "$TITLE_FILE" --rawfile desc "$DESC_FILE" \
  '{ sourceRefName: $src, targetRefName: $tgt, title: $title, description: $desc }' > "$BODY"
```

- レビュアー指定はユーザーが明示した場合のみ `reviewers: [{ id: "<GUID>" }]` を付与（GUID はセクション 4 の Identity 解決を流用）
- 成功時: レスポンスの `pullRequestId` から PR URL（`{base}/{project}/_git/{repo}/pullrequest/{id}`）を組み立てて報告する

## 3. PR コメント投稿

### 新規スレッド作成（PR 全体コメント）

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke --area git --resource pullRequestThreads --route-parameters project={project} repositoryId={repo} pullRequestId={prId} --org {base} --api-version 7.1 --http-method POST --in-file "$BODY"` |
| TFS | `POST {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}/threads?api-version=6.0` |

body:

```bash
jq -n --rawfile content "$CONTENT_FILE" \
  '{ comments: [{ parentCommentId: 0, content: $content, commentType: 1 }], status: "active" }' > "$BODY"
```

### インラインコメント（ファイルパス・行範囲指定付きスレッド作成）

差分の特定行範囲に紐づくコメントスレッドを作成する。`threadContext` を含めてスレッドを POST する。

一時ファイルは safe-api-access.md セクション 3 の 5 変数管理（`NETRC` / `BODY` / `RESP` / `CONTENT_FILE` / `PATH_FILE`）に含まれ、`cleanup_secrets` の trap で自動削除される。

body:

```bash
# CONTENT_FILE / PATH_FILE は cleanup_secrets の管理対象（safe-api-access.md セクション 3）
CONTENT_FILE=$(mktemp); chmod 600 "$CONTENT_FILE"
PATH_FILE=$(mktemp); chmod 600 "$PATH_FILE"
printf '%s' "$comment_body" > "$CONTENT_FILE"
# 二重スラッシュで MSYS パス自動変換を回避し jq 内で正規化
printf '%s' "//${file_path#/}" > "$PATH_FILE"

jq -n \
  --rawfile content "$CONTENT_FILE" \
  --rawfile path    "$PATH_FILE" \
  --argjson sl "$start_line" \
  --argjson el "$end_line" \
  '{
    comments: [{ parentCommentId: 0, content: $content, commentType: 1 }],
    threadContext: {
      filePath: ($path | sub("^//"; "/")),
      rightFileStart: { line: $sl, offset: 1 },
      rightFileEnd:   { line: $el, offset: 1 }
    },
    status: "active"
  }' > "$BODY"
```

- `filePath`: `/` 始まりのリポジトリルート相対パス（例: `/src/web/admin/OrderSearch.cs`）
- `rightFileStart` / `rightFileEnd`: 差分の右側（変更後）の行範囲。単一行の場合は start = end
- `--rawfile` 経由でファイルパスを渡す（`--arg` は Windows Git Bash の MSYS パス自動変換で破綻する。safe-api-access.md セクション 4）
- 投稿成功時のレスポンスから `id`（threadId）を取得し、呼び出し元に返す

### 既存スレッドへの返信

```text
POST .../pullrequests/{prId}/threads/{threadId}/comments?api-version={v}
body: { "content": <本文>, "parentCommentId": <親コメント ID>, "commentType": 1 }
```

### PR スレッド一覧取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke --area git --resource pullRequestThreads --route-parameters project={project} repositoryId={repo} pullRequestId={prId} --org {base} --api-version 7.1 --output json` |
| TFS | `GET {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}/threads?api-version=6.0` |

- 主要フィールド: `value[]` 配列。各スレッドに `id` / `status` / `threadContext`（`filePath` / `rightFileStart` / `rightFileEnd`）/ `comments[]`（`content` / `author.displayName` / `publishedDate`）/ `isDeleted`
- フィルタ: レスポンス全量を取得し、呼び出し元で `status` / `isDeleted` / `threadContext` 有無でフィルタする

### PR スレッドステータス変更

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke --area git --resource pullRequestThreads --route-parameters project={project} repositoryId={repo} pullRequestId={prId} threadId={threadId} --org {base} --api-version 7.1 --http-method PATCH --in-file "$BODY"` |
| TFS | `PATCH {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}/threads/{threadId}?api-version=6.0` |

body:

```bash
jq -n --arg s "$new_status" '{ status: $s }' > "$BODY"
```

- `new_status`: `active` / `fixed` / `closed` / `wontFix` / `byDesign` / `pending`
- 成功時: レスポンスの `status` が指定値と一致することを確認

## 4. PR 承認（vote）

### vote 値

| vote | 意味 |
|------|------|
| 10 | 承認（Approved） |
| 5 | 提案付き承認（Approved with suggestions） |
| 0 | 未投票（リセット） |
| -5 | 作成者の対応待ち（Waiting for author） |
| -10 | 却下（Rejected） |

**承認はユーザー本人の意思表示の代行**。実行前に vote 値と対象 PR を明示して `AskUserQuestion` で確認する（SKILL.md Step 4）。

### 自分（認証ユーザー）の ID 取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke` では取得できないため `az rest` を使用: `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url "{base}/_apis/connectionData" --query authenticatedUser.id -o tsv` |
| TFS | `GET {base}/_apis/connectionData` （NTLM）→ `.authenticatedUser.id` |

### vote 設定

```text
PUT {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}/reviewers/{reviewerId}?api-version={v}
body: { "vote": 10 }
```

- 成功時: レスポンスの `vote` が指定値と一致することを確認して報告する

## 5. PR メタ情報更新

```text
PATCH {base}/{project}/_apis/git/repositories/{repo}/pullrequests/{prId}?api-version={v}
```

| 更新対象 | body 例 | 前提 |
|---------|--------|------|
| タイトル / 説明 | `{ "title": ..., "description": ... }` | description は render-check（`ado-markdown`）必須 |
| 中止（abandon） | `{ "status": "abandoned" }` | 影響が大きいため対象 PR・現状態を提示して承認必須 |
| 再アクティブ化 | `{ "status": "active" }` | 同上 |

- **complete（マージ）は本スキルでは実行しない**（マージはレビュープロセス・ブランチポリシーに直結するため。ユーザーが明示的に依頼した場合も、Web UI での操作を案内する）
- 変更前の値（現タイトル・現説明）を取得して「変更前 → 変更後」を提示してから承認を得る

## 6. commit 情報取得

### commit 詳細

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke --area git --resource commits --route-parameters project={project} repositoryId={repo} commitId={commitId} --org {base} --api-version 7.1 --output json` |
| TFS | `GET {base}/{project}/_apis/git/repositories/{repo}/commits/{commitId}?api-version=6.0` |

- 主要フィールド: `commitId` / `comment`（コミットメッセージ）/ `author.name` / `author.date` / `changeCounts`（Add / Edit / Delete）

### commit の変更ファイル一覧

| 種別 | 方法 |
|-----|------|
| クラウド | `az devops invoke --area git --resource commits --route-parameters project={project} repositoryId={repo} commitId={commitId} --query-parameters 'changeCount=1000' --org {base} --api-version 7.1 --output json` |
| TFS | `GET {base}/{project}/_apis/git/repositories/{repo}/commits/{commitId}/changes?api-version=6.0` |

- 主要フィールド: `changes[]` — `item.path` / `changeType`（add / edit / delete / rename）

### commit 間の diff

| 種別 | 方法 |
|-----|------|
| クラウド | `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url "{base}/{project}/_apis/git/repositories/{repo}/diffs/commits?baseVersion={base-commit}&targetVersion={target-commit}&api-version=7.1" --output json` |
| TFS | `GET {base}/{project}/_apis/git/repositories/{repo}/diffs/commits?baseVersion={base-commit}&targetVersion={target-commit}&api-version=6.0` |

- 主要フィールド: `changes[]` — `item.path` / `changeType` / 各ファイルの変更詳細

## 7. Azure Pipelines 読み取り

### ビルド結果取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az pipelines runs show --id {buildId} --org {base} --project {project} --output json` |
| TFS | `GET {base}/{project}/_apis/build/builds/{buildId}?api-version=6.0` |

- 主要フィールド: `id` / `buildNumber` / `status`（completed / inProgress / cancelling 等）/ `result`（succeeded / partiallySucceeded / failed / canceled）/ `sourceBranch` / `requestedFor.displayName` / `startTime` / `finishTime`

### テスト結果取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url "{base}/{project}/_apis/test/runs?buildUri=vstfs:///Build/Build/{buildId}&api-version=7.1" --output json` |
| TFS | `GET {base}/{project}/_apis/test/runs?buildUri=vstfs:///Build/Build/{buildId}&api-version=6.0` |

- 主要フィールド: `value[]` — `id` / `name` / `totalTests` / `passedTests` / `failedTests` / `state` / `completedDate`
- 個別テスト結果: `GET .../test/runs/{runId}/results?api-version={v}` で `testCaseTitle` / `outcome` / `errorMessage` / `stackTrace` を取得

### ビルドログ取得

| 種別 | 方法 |
|-----|------|
| クラウド | `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url "{base}/{project}/_apis/build/builds/{buildId}/logs?api-version=7.1" --output json` |
| TFS | `GET {base}/{project}/_apis/build/builds/{buildId}/logs?api-version=6.0` |

- ログ一覧を取得後、個別ログ: `GET .../builds/{buildId}/logs/{logId}` でテキスト取得
- ログは大量になり得るため、呼び出し元が必要なログ ID を指定する設計を推奨

### パターン B（委譲）での Pipelines 読み取り

CI テストエラーの内容を取得して呼び出し元に渡す場合:

```text
Skill(skill: "connector:azure", args: "読み取りのみ。<org-url> のプロジェクト <project> のビルド <buildId> の結果・テスト結果・ログを取得して")
```

connector は取得結果を **解釈・要約せずそのまま** 呼び出し元に返す。呼び出し元（coding / code-review 等）がエラー内容を解析して次のアクションを決定する。

**シークレット注記**: Azure DevOps Pipelines はシークレット変数（`$(secret_var)`）をログ出力時に自動マスク（`***`）するが、ユーザー定義のカスタムログ出力（`echo` / `Write-Host` 等）に秘密情報が平文で含まれる可能性がある。パターン B でログを透過的に返す際は、返却前にシークレットパターン（API キー・トークン・パスワード等の正規表現。safe-api-access.md の機密情報検出パターンを流用）の簡易チェックを実施し、検出時は呼び出し元に警告を付与する。

## 8. 結果検証・報告

- 全操作: HTTP コード 2xx + レスポンスの ID / 状態の一致を確認してから成功と報告する
- 報告には対象 URL（PR URL）を含める
- 期待と異なるレスポンスの場合は直ちにユーザーへ報告する（黙ってリトライ・追加修正しない）
