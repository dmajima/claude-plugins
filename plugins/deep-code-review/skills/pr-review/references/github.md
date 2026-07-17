# GitHub PR 操作リファレンス

> **本ファイルは connector:github の内部実装リファレンス（デバッグ・トラブルシューティング用）として維持する。pr-review からの直接 gh CLI 実行は廃止され、すべて `connector:github` 経由で操作する。** pr-review の投稿フローは `comment-posting.md` セクション 7.1 を参照。

`pr-review` スキルが GitHub の PR を扱う際のコマンド・API 詳細を記載する。

---

## 1. 認証

### 推奨方式: OAuth（ブラウザ）

```bash
gh auth login
gh auth status
```

最も安全。トークン管理は gh CLI と OS の安全な保管領域に委ねる。

### 推奨方式: 環境変数 `GH_TOKEN`

セッション限定でメモリ上のみに保持する場合:

```bash
# bash / wsl
read -s GH_TOKEN
export GH_TOKEN
gh auth status

# PowerShell
$env:GH_TOKEN = (Read-Host -AsSecureString | ConvertFrom-SecureString -AsPlainText)
```

`read -s` / `Read-Host -AsSecureString` を使うことで、シェル履歴・プロセス引数・ログに **平文で残らない**。

### 禁止事項

- ❌ **`token.txt` 等の平文ファイルにトークンを保存しない**（リポジトリへの誤コミット・他プロセスからの読み取りリスク）
- ❌ `gh auth login --with-token < token.txt` のような例示は使用しないこと
- ❌ コマンドライン引数（`--token <PAT>`）に直接トークンを渡さない（プロセス一覧から漏洩する）

### 必要スコープ

- `repo`（プライベートリポも扱う場合）
- `read:org`（組織リポの場合）
- `pull_request`（PR コメント追加・スレッド管理）

---

## 2. PR メタ情報の取得

### 基本情報

```bash
gh pr view <N> --json number,title,body,state,isDraft,baseRefName,headRefName,headRepository,url,author,reviews
```

### 変更ファイル一覧

```bash
gh pr view <N> --json files
# あるいは
gh pr diff <N> --name-only
```

### 差分（パッチ）

```bash
gh pr diff <N>
gh pr diff <N> --patch    # patch 形式
```

### コミット履歴

```bash
gh pr view <N> --json commits
```

---

## 3. レビュースレッド・コメント

### 全スレッド・解決状態取得（GraphQL）

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

### スレッドの解決（resolve）

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -f threadId=<thread-id>
```

### スレッドの再オープン（unresolve）

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    unresolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -f threadId=<thread-id>
```

---

## 4. インラインコメントの追加

> **コマンドインジェクション対策（必須）**: コメント本文・ファイルパス等のユーザー入力由来の値は **必ず `jq --arg` / `--argjson` 経由で JSON body を構築** し、`gh api --input -`（stdin）で渡す。シェル文字列に直接埋め込まない。

### 単一行コメント

```bash
jq -n \
  --arg body "<コメント本文>" \
  --arg commit_id "<head-sha>" \
  --arg path "<ファイルパス>" \
  --argjson line <行番号> \
  '{body: $body, commit_id: $commit_id, path: $path, line: $line, side: "RIGHT"}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/comments --input -
```

### 複数行（範囲指定）コメント

```bash
jq -n \
  --arg body "<コメント本文>" \
  --arg commit_id "<head-sha>" \
  --arg path "<ファイルパス>" \
  --argjson start_line <開始行> \
  --argjson line <終了行> \
  '{body: $body, commit_id: $commit_id, path: $path, start_line: $start_line, start_side: "RIGHT", line: $line, side: "RIGHT"}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/comments --input -
```

### レビュー一括投稿（複数コメントをまとめて）

```bash
# コメント配列を jq で安全に構築
jq -n \
  --arg body "レビューサマリ" \
  --argjson comments '[
    {"path":"file.ts","line":10,"body":"comment 1"},
    {"path":"file.ts","start_line":20,"line":25,"side":"RIGHT","body":"comment 2"}
  ]' \
  '{event: "COMMENT", body: $body, comments: $comments}' \
  | gh api repos/<owner>/<repo>/pulls/<N>/reviews --input -
```

> 配列内のコメント本文も LLM 生成テキストの場合は、各コメントを個別に `jq` で構築してから `--slurp` で配列化することを推奨。詳細は `pr-review/SKILL.md` の Step 7 を参照。

---

## 5. PR 全体へのコメント

```bash
gh pr comment <N> --body "<コメント本文>"
```

レビューサマリは原則こちらで投稿。インラインコメントは個別指摘用。

---

## 6. リポ情報の解析

PR URL から owner / repo / number を抽出:

```
https://github.com/<owner>/<repo>/pull/<number>
```

ID 単体（`#123` / `123`）の場合は `git remote -v` から `origin` の URL を取得し、`github.com/<owner>/<repo>(.git)?` パターンでパースする。

---

## 7. 範囲指定コメントの注意

- `line` は **PR 差分上の最終行**（1-indexed）
- `start_line` を指定する場合は `start_side` も必須（通常 `RIGHT`）
- `side`: `RIGHT` = 変更後（追加行）、`LEFT` = 変更前（削除行）。一般的には `RIGHT`
- `commit_id` は **PR の head SHA**。`gh pr view <N> --json headRefOid -q .headRefOid` で取得

---

## 8. レート制限

- GraphQL: 5,000 ポイント/時（認証済み）
- REST: 5,000 リクエスト/時（認証済み）

大量コメント追加時はレート制限に注意。1 PR あたり数十件程度なら問題なし。

---

## 9. github プラグイン MCP との関係（connector:github 内部実装の参考情報）

> 本セクションは connector:github の内部実装に関する参考情報であり、pr-review の動作には直接関係しない。

本プラグインは **dependencies** として `github@claude-plugins-official` を含む。
github プラグインは `api.githubcopilot.com/mcp/` 経由で同等の操作を提供するため、MCP ツールが利用可能な場合はそちら経由でも実行可能。

ただし、`gh` CLI の方が:
- 認証が単純（`gh auth login` 一度のみ）
- スクリプト統合が容易
- レート制限が独立

なので、本リファレンスは **`gh` CLI を主軸** に記述している。MCP ツールは補助的に使う。
