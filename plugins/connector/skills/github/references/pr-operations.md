# GitHub PR 操作 API（詳細実装）

`github` スキルの PR 操作（取得・コメント投稿・Pending Review・スレッド操作）の詳細実装。

コマンドインジェクション対策: コメント本文・ファイルパス等は **必ず `jq --arg` / `--argjson` 経由で JSON body を構築** し、`gh api --input -`（stdin）で渡す。

## 1. PR 情報取得

### メタ情報

```bash
gh pr view <N> --repo <owner>/<repo> --json number,title,body,state,isDraft,baseRefName,headRefName,url,author,reviews
```

### 変更ファイル一覧

```bash
gh pr view <N> --repo <owner>/<repo> --json files
```

### 差分

```bash
gh pr diff <N> --repo <owner>/<repo>
```

### コミット履歴

```bash
gh pr view <N> --repo <owner>/<repo> --json commits
```

### HEAD SHA 取得

```bash
gh pr view <N> --repo <owner>/<repo> --json headRefOid -q .headRefOid
```

## 2. レビュースレッド一覧取得（GraphQL）

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            startLine
            comments(first: 50) {
              nodes {
                id
                body
                author { login }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -F owner=<owner> -F repo=<repo> -F number=<N>
```

- 主要フィールド: `reviewThreads.nodes[]` — `id` / `isResolved` / `isOutdated` / `path` / `line` / `startLine` / `comments[]`
- フィルタ: 呼び出し元で `isResolved` / `isOutdated` でフィルタする

## 3. インラインコメント投稿

### 単一行コメント

```bash
jq -n \
  --arg body "$comment_body" \
  --arg commit_id "$head_sha" \
  --arg path "$file_path" \
  --argjson line "$line_number" \
  '{body: $body, commit_id: $commit_id, path: $path, line: $line, side: "RIGHT"}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/comments --input -
```

### 複数行（範囲指定）コメント

```bash
jq -n \
  --arg body "$comment_body" \
  --arg commit_id "$head_sha" \
  --arg path "$file_path" \
  --argjson start_line "$start_line" \
  --argjson line "$end_line" \
  '{body: $body, commit_id: $commit_id, path: $path, start_line: $start_line, start_side: "RIGHT", line: $line, side: "RIGHT"}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/comments --input -
```

- `commit_id`: PR の HEAD SHA（セクション 1 で取得）
- `side`: `RIGHT`（変更後）が標準。`LEFT`（変更前）は削除行への指摘時のみ
- 投稿成功時のレスポンスから `id` を取得し、呼び出し元に返す

## 4. Pending Review 一括投稿

5 件以上のコメントをまとめて投稿する場合に使用。通知が 1 件に集約される。

```bash
jq -n \
  --arg body "$review_summary" \
  --argjson comments "$comments_json_array" \
  '{event: "COMMENT", body: $body, comments: $comments}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/reviews --input -
```

- `$comments_json_array`: `[{"path":"file.ts","line":10,"body":"comment 1"}, ...]` 形式の JSON 配列文字列
- 各コメントの `body` も LLM 生成テキストの場合は、個別に `jq` で構築してから `--slurp` で配列化することを推奨

## 5. PR 全体コメント投稿

```bash
jq -n --arg body "$comment_body" '{body: $body}' \
  | gh api repos/<owner>/<repo>/issues/<N>/comments --input -
```

- PR 全体コメントは Issues API 経由（GitHub では PR は Issue のサブタイプ）

## 6. 既存コメントへの返信

```bash
jq -n --arg body "$reply_body" '{body: $body}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment_id>/replies --input -
```

## 7. スレッド resolve / unresolve

### resolve

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -f threadId="$thread_id"
```

### unresolve

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    unresolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -f threadId="$thread_id"
```

- 成功時: `thread.isResolved` が期待値（resolve: `true` / unresolve: `false`）と一致することを確認

## 8. URL 解析

PR URL パターン: `https://github.com/<owner>/<repo>/pull/<number>`

ID 単体（`#123` / `123`）の場合は `git remote -v` から `origin` の URL を取得し、`github.com/<owner>/<repo>(.git)?` パターンでパースする。

## 9. レート制限

| API | 制限 | 備考 |
|-----|------|------|
| REST | 5,000 リクエスト/時 | 認証済み |
| GraphQL | 5,000 ポイント/時 | 認証済み |

大量コメント追加時はレート制限に注意。1 PR あたり数十件程度なら問題なし。
