# Step 7 詳細: インラインコメント投稿（セクション 7.0〜7.4）

`pr-review` スキル Step 7 のインラインコメント投稿に関する詳細実装。Finding ID 表示・GitHub / Azure DevOps への投稿委譲・サニタイズ・HTTP エラー分岐を扱う。

> **親ファイル**: [`comment-posting.md`](comment-posting.md)（Step 7 の概要・セクションマップ）。サマリースレッド投稿（セクション 7.5〜7.7）は [`comment-posting-summary.md`](comment-posting-summary.md) を参照。

---

## 7.0 PR コメント本文の Finding ID 表示（必須）

PR にインラインコメント / サマリースレッドを投稿する際、**本文冒頭に Finding ID を表示** する。
ユーザーが PR 上で「この指摘を直して」と言うときに ID で一意特定できるようにするため。

### 7.0.1 インラインコメント本文の冒頭フォーマット

```
## [CR-001] [Critical] SQL インジェクション可能性

検索キーワードを string.Format で SQL に直結している。パラメータ化クエリ未使用。
...
```

- 1 行目: **`## [<Finding ID>] [<致命度>] <タイトル>` の形式（必ず Markdown H2 見出し `## ` で始める）**
- ID と致命度はそれぞれ `[ ]` で囲む（コードフェンス外でも自動リンク化されない記号）
- 2 行目以降: 統合サマリの各指摘セクションをそのまま貼り付け
- タイトルを H2 にする目的: PR 上で開いた際に「これがどの Finding ID で、どの致命度で、何の指摘か」を見出しレベルで識別でき、Markdown レンダラの目次・アウトライン機能でも一覧化できるようにする
- 注意: H2 にしたことでコメント本文内のサブ見出し（「指摘内容」「求める修正」「理由・根拠」等）は H3（`###`）以降を使う

### 7.0.2 サマリースレッドの目次

サマリースレッド本文の **冒頭ヘッダブロック直後** に、Finding ID 一覧の目次を `<details>` 折り畳み + 内部 HTML 記法で含める:

```html
<details>
<summary>検出した指摘・提案一覧（Finding ID）</summary>
<h2>検出した指摘・提案一覧（Finding ID）</h2>

<table>
    <tr>
        <th>ID</th>
        <th>区分</th>
        <th>致命度 / Impact</th>
        <th>タイトル</th>
        <th>該当箇所</th>
    </tr>
    <tr>
        <td>CR-001</td>
        <td>Issue</td>
        <td>Critical</td>
        <td>SQL インジェクション可能性</td>
        <td><code>src/web/admin/OrderSearch.cs:140-148</code></td>
    </tr>
    <tr>
        <td>CR-002</td>
        <td>Suggestion</td>
        <td>HIGH×MED</td>
        <td>N+1 クエリ最適化</td>
        <td><code>src/cart/CartService.cs:200-220</code></td>
    </tr>
</table>
</details>
```

> **目次配置**: ヘッダブロック直後・セクション 1（対応が必要な指摘）の `<details>` ブロックの前。
> ユーザーが ID と概要だけを一覧で確認できるようにし、詳細は対応セクションで参照する。

### 7.0.3 ID と PR コメントの紐付け

オーケストレーターから返却されたサマリーには Finding ID 付きで指摘が含まれているため、`pr-review` 側で **個別インラインコメントを投稿する際、その本文に必ず Finding ID を含める**。

> **記法の変換（必須）**: インラインコメントは `<details>` で囲まない Markdown 文脈のため、サマリー本文（HTML 記法）から表・コード・見出しを流用する場合は **Markdown 記法（`|` テーブル / コードフェンス / `##`〜`###` 見出し）に変換** する。HTML の `<table>` / `<pre><code>` をインラインコメントへそのまま貼らない。

実装上の流れ:

```
統合サマリ本文（CR-001 〜 CR-NNN 採番済み）
   ↓
pr-review が各 Finding ID ごとに以下を組み立て
   - インラインコメント本文（冒頭 ## [CR-NNN] [致命度] タイトル + 詳細）
   - threadContext.filePath / rightFileStart / rightFileEnd（指摘箇所）
   ↓
1 件ずつ API 投稿（本ファイル セクション7.1 / セクション7.2 のフォーマットに従う）
   ↓
投稿後、API レスポンスの thread_id を取得 → サマリースレッド本文の ID 列を
[CR-NNN](URL) 形式の明示リンクに置換（URL 形式は セクション7.0.4 を参照）
```

### 7.0.4 サマリースレッドの ID リンク URL（必須形式）

サマリースレッド セクション1-A / セクション2-A / セクション3-A の表で `ID` 列を PR インラインコメントへリンクする際の URL 形式:

#### TFS / Azure DevOps

```
https://<host>/.../pullrequest/<N>?_a=files&path=<file-path>&discussionId=<thread-id>
```

- `_a=files`（必須）— Files タブで開く
- **`path=<file-path>`（必須・要注意）** — `/` 始まりのリポジトリルート相対パス（例: `/plugins/deep-code-review/skills/pr-review/SKILL.md`）。**`path=` を省略するとサーバ側でファイルが特定できず該当インラインコメントへ正しく遷移しない**
- `discussionId=<thread-id>`（必須）— 投稿先スレッドの ID（API レスポンスの `id`）
- URL エンコードが必要な文字（空白・日本語・特殊記号）はエンコードする

#### GitHub

```
https://github.com/<owner>/<repo>/pull/<N>#discussion_r<comment-id>
```

詳細仕様・Markdown サンプルは `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` セクション2.6 を参照（SSOT）。

---

## 7.1 GitHub のインラインコメント（connector:github 委譲）

> **委譲設計**: GitHub の PR コメント投稿は `connector:github` スキルに委譲。pr-review はコメント本文の組み立て・バリデーション・テンプレート適用を担当し、投稿操作を connector に渡す。
>
> API 実装の詳細（gh CLI コマンド・jq body 構築・GraphQL 等）は connector プラグインの `skills/github/references/pr-operations.md` を参照。

### 7.1.1 インラインコメント投稿（connector 委譲）

投稿前バリデーション（7.0 / 7.3）を通過した各 Finding について、以下のパターンで connector:github を呼び出す:

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> にインラインコメントを投稿。ファイル: <filePath>, 開始行: <startLine>, 終了行: <endLine>, commit: <headSHA>, 本文: <comment_body>。承認済み。")
```

### 7.1.2 Pending Review 一括投稿（connector 委譲）

指摘件数が多い場合（5件以上）は Pending Review でまとめて投稿する（通知の集約・レビュー単位の管理性が向上）:

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> に Pending Review を投稿。サマリー: <review_summary>, コメント: <comments_json_array>。承認済み。")
```

### 7.1.3 PR 全体コメント投稿（connector 委譲）

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> にコメントを投稿。本文: <summary_body>。承認済み。")
```

### 7.1.4 スレッド resolve（connector 委譲）

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のスレッド <threadId> を resolve。承認済み。")
```

### 7.1.5 既存コメントへの返信（connector 委譲）

```text
Skill(skill: "connector:github", args: "PR URL: <PR_URL> のコメント <commentId> に返信。本文: <reply_body>。承認済み。")
```

---

## 7.2 Azure DevOps のインラインコメント（connector:azure 委譲）

> **委譲設計**: Azure DevOps の PR コメント投稿は `connector:azure` スキルに委譲。pr-review はコメント本文の組み立て・バリデーション・テンプレート適用を担当し、投稿操作を connector に渡す。
>
> API 実装の詳細（NETRC パターン・jq body 構築・MSYS パス変換回避等）は connector プラグインの `skills/azure/references/pr-operations.md` を参照。

### 7.2.1 インラインコメント投稿（connector 委譲）

投稿前バリデーション（7.0 / 7.3）を通過した各 Finding について、以下のパターンで connector:azure を呼び出す:

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> にインラインコメントを投稿。ファイル: <filePath>, 開始行: <startLine>, 終了行: <endLine>, 本文: <comment_body>。render-check 通過済み。承認済み。")
```

- `<filePath>`: `/` 始まりのリポジトリルート相対パス（例: `/src/Controllers/OrderController.cs`）
- `<startLine>` / `<endLine>`: 差分の右側（変更後）の行範囲。単一行の場合は同一値
- `<comment_body>`: 7.0.1 のフォーマットに従った本文（`## [CR-NNN] [致命度] タイトル` + 詳細）
- `「render-check 通過済み。承認済み。」` の明示は **必須**（pr-review の Step 7 で投稿前バリデーションとユーザー承認を実施済みのため）
- connector からのレスポンスでスレッド `id`（threadId）を取得し、7.0.4 のリンク URL 構築と 7.4 の Finding → Thread マッピングに使用する

### 7.2.2 サマリースレッド投稿（connector 委譲）

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> にコメントスレッドを投稿。本文: <summary_body>。render-check 通過済み。承認済み。")
```

### 7.2.3 既存スレッドへの返信（connector 委譲）

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <threadId> に返信。本文: <reply_body>。render-check 通過済み。承認済み。")
```

### 7.2.4 スレッドステータス変更（connector 委譲）

```text
Skill(skill: "connector:azure", args: "PR URL: <PR_URL> のスレッド <threadId> のステータスを <status> に変更。承認済み。")
```

> **GitHub PR の投稿** はセクション 7.1 の `connector:github` 経由で行う。

---

## 7.3 コメント本文のサニタイズ（必須）

PR にコメント追記する前のサニタイズ規則は **プラグイン共通リファレンス `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` に集約済み**。本ファイルからは規則の参照のみ示す。

要点（詳細は `comment-sanitization.md` セクション 3〜4）:

- コードフェンス必須・`<img>` 削除・外部画像 Markdown 削除・危険スキーム（`javascript:` / `data:` / `vbscript:` / `file:`）リンク剥離
- 機密文字列の伏字化: Bearer / Basic / GHP / Fine-grained PAT / JWT / AWS / GCP / Slack
- **疑わしい場合は伏字側に倒す**（false positive 許容）

サニタイズ済みの本文文字列を組み立て、connector 呼び出し時の args に含める（JSON body の構築は connector 側の責務）。

---

## 7.4 HTTP ステータス分岐とレート制限・エラー時のロールバック

> **詳細実装はプラグイン共通リファレンス `${CLAUDE_PLUGIN_ROOT}/references/http-error-handling.md` を参照**（本セクションはプラグイン共通 Cross-Cutting Concern として昇格済み）。

要点:

- HTTP エラーハンドリングは **connector 側が担当**（connector プラグインの `references/http-error-handling.md` / `references/safe-api-access.md` に従う）
- pr-review 側は connector 呼び出しが失敗した場合の **未送信件数の報告** と **部分失敗時のロールバック判断** に責務を限定する
- 部分失敗時: 既存状態を巻き戻さず、未送信件数を完了報告（Step 8）に明示
- connector が認証エラー（401/403 相当）を返した場合: pr-review は投稿を即停止し、ユーザーに認証確認を案内する
