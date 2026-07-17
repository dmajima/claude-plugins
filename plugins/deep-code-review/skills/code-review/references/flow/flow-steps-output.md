# レビュー実行フロー — 出力・状態 Step（8〜8.5）

> 親: [flow.md](flow.md)（全体図・用語定義・Step 索引）。本ファイルは **出力・状態フェーズ**（Step 8 / Step 8.5）の詳細を保持する。
> 前フェーズ: 準備〜動員決定（Step 0-P〜3.5）は [flow-steps-early.md](flow-steps-early.md)、レビュー実行（Step 4〜7）は [flow-steps-review.md](flow-steps-review.md) を参照。

---

## Step 8: 統合サマリ出力

`output-format.md` の出力フォーマットに従い、最終サマリを生成する。

### 出力先

- メインコンテキストへの **テキスト返却** が基本
- `pr-review` から呼ばれた場合は構造化された結果を **フロー内部データとして** 返却し、`pr-review` が PR にコメント追記。ユーザー向けメッセージとして整形したり、「レビュー結果は以下の通りです」等の対話的な導入文を付けたりしてはならない（pr-review が受領後 Step 7 に自動進行するため）
- ユーザーがファイル出力を希望した場合は Step 8.5 で出力済みの `.claude/.local/plugins/deep-code-review/{branch}/{timestamp}/review-summary.md` のパスを案内する

### 必須セクション（すべて日本語・順序固定）

統合サマリは **必ず** `template/review-summary.md` の統一フォーマットで出力する。**毎回同一のレイアウト** を厳守し、該当なしのセクションも `<details>` ブロックを残し本文に「該当なし」と記載する（ブロックを削除しない）。
各 H2 セクションは `<details><summary><見出し></summary>` + `<h2>` 再掲の折り畳み形式・内部 HTML 記法で出力する（タイトル行・ヘッダブロックは折り畳み対象外）。

1. **タイトル + ヘッダブロック**: `# 🤖 [deep-code-review-plugin] PR レビューサマリー （第 <N> 回）` + レビュー結果（統合フィールド）/ 件数 / 実施日時 / 対象 head SHA / レビュー対象 / レビューモード
2. `1. 対応が必要な指摘 （X 件）` — Issues 全件・重要度順
3. `2. 改善提案 （X 件）` — Low 改善提案・Impact×Effort 順・最大10件
4. `3. スコープ外指摘 （X 件）` — 本 PR スコープ外の指摘（別 PR 推奨はしない）
5. `4. 観点別の指摘なし` — エージェント単位で1行集約
6. `5. 観点間の見解の差異` — 衝突がある場合のみ・なければ「該当なし」
7. `6. 既存指摘の解消判定 （X 件 ／ 再レビュー時のみ）` — `pr-review` 再レビュー時のみ・初回は「該当なし」
8. `7. 未確認事項・制約` — SKIPPED 等。「未実施」を「問題なし」と書き換えない
9. `8. 集計` — 実施日時・モード・参加観点別スキル・比較ブランチ・参照規約・参照仕様書 等
10. `9. レビュー実施環境` — `pr-review` 経由時の worktree 作成・処理状況。それ以外は「該当なし」

詳細は `output-format.md` セクション 1〜2 と `template/review-summary.md` を参照。

---

## Step 8.5: state.yaml 出力（必須）

Step 8 完了直後に、レビュー結果を state.yaml として永続化する。

### 8.5-1: タイムスタンプフォルダ作成（出力先パスの厳守）

```
REPO_ROOT/.claude/.local/plugins/deep-code-review/{branch_name}/{yyyyMMdd_HHmmss}/
```

ブランチ名に `/` を含む場合はそのままディレクトリ階層化する。

> **禁止**: `.claude/.local/work/{session}/` に state.yaml / review-summary.md を保存すること。
> state.yaml はブランチ単位で永続化するプラグインデータであり、セッション作業領域とは管理体系が異なる。
> セッション作業領域に保存すると、再レビュー時の前回 state 読み込み（Step 0-P-2）が失敗する。

### 8.5-1.1: 出力先パスの検証（必須）

フォルダ作成後、以下を確認する:

1. 作成したパスが `.claude/.local/plugins/deep-code-review/` で始まること
2. `.claude/.local/work/` を含まないこと
3. ブランチ名ディレクトリとタイムスタンプディレクトリが含まれること

### 8.5-2: state.yaml の生成

`${CLAUDE_SKILL_DIR}/references/template/state/state_template.yaml` のプレースホルダを埋める。

| プレースホルダ | 値の取得元 |
|---------------|-----------|
| `branch` | Step 0-P-1 で取得したブランチ名 |
| `reviewed_at` | 現在日時 |
| `git_head` | `git rev-parse --short HEAD` |
| `review_round` | Step 0-P-2 で算出した回数 |
| `mode` | Step 0 で選択したモード |
| `verdict` | Step 7 の判定結果 |
| `previous_review_dir` | Step 0-P-2 で読み込んだ前回フォルダ名 |
| `counts` | Step 5-6 の集計結果 |
| `findings` | Step 6 で採番した全 Finding ID と詳細 |
| `remaining_issues` | Step 5 の解消確認で未解消と判定された前回指摘 |
| `resolved_since_last` | Step 5 の解消確認で解消と判定された前回指摘 |
| `ignored_by_user` | 前回 state + 今回ユーザーが除外指示した項目 |
| `inputs_used` | Step 0-P-3 / Step 2 で読み込んだ inputs ファイル一覧 |
| `code_as_reference_decisions` | コード信頼性のユーザー承認記録 |

### 8.5-3: detail_summary の記述

**各 finding の `detail_summary` は、再レビュー時に前回指摘を正確に理解するための鍵。**
以下を含めること:

- 問題が発生するファイルパスと行範囲
- 具体的な問題内容（何が・なぜ問題か）
- 期待される修正方針
- 関連する規約・仕様への参照

### 8.5-4: PR Thread ID の記録

PR レビュー時（`pr-review` 経由）で PR にコメントを投稿した場合、各 finding に:

- `pr_thread_id`: Azure DevOps thread ID / GitHub comment ID
- `pr_thread_url`: PR コメントへの完全 URL
- `pr_thread_status`: スレッドの状態（active / fixed / wontFix / closed）

を記録する。`finding-thread-map.json`（pr-review の Step 7.4）と整合性を保つ。

#### Thread ID の受渡しインターフェース

`code-review` は PR 識別子を直接処理しない設計のため、Thread ID は以下の経路で取得する:

| 呼び出し元 | 受渡し方法 | 取得タイミング |
|-----------|-----------|--------------|
| `pr-review` → `code-review` | `pr-review` がレビュー結果を PR に投稿後、`finding-thread-map.json` をセッション作業領域に保存（pr-review Step 7.4） | Step 8.5 実行時 |
| `code-review` 単独実行（PR 経由でない場合） | Thread ID なし。`pr_thread_id` / `pr_thread_url` / `pr_thread_status` は全て `null` | Step 8.5 実行時 |

Step 8.5 では、`finding-thread-map.json` が存在する場合はその内容を Finding ID で照合し、state.yaml の各 finding に Thread ID を転記する。存在しない場合は Thread ID 関連フィールドを `null` のままとする。

#### 投稿失敗時の Thread ID 処理

PR コメント投稿が部分的に失敗した場合（HTTP 400/500 等）:

| 状況 | pr_thread_id | pr_thread_status | finding.status |
|------|-------------|-----------------|----------------|
| 投稿成功 | 取得した Thread ID（文字列） | `active` | `open` |
| 投稿失敗 | `null` | `null` | `open`（`post_failed: true` を付記） |
| 投稿未実施（非 PR レビュー） | `null` | `null` | `open` |

投稿失敗した finding は state.yaml に `post_failed: true` フラグを付記する。次回レビュー時にこのフラグがある finding は再投稿を試みる。

### 8.5-5: 投稿結果に応じた finding.status 更新

Step 7（PR コメント投稿）の結果に基づき、state.yaml の各 finding の status を更新する:

| 投稿結果 | finding.status の更新 |
|---------|---------------------|
| PR インラインコメント投稿成功 | `open`（初期状態のまま。PR 上で解消されるまで open） |
| PR インラインコメント投稿失敗 | `open` + `post_failed: true`（再投稿対象としてマーク） |
| ユーザーが `ack-scope-out` で了承 | `scope_out` |
| ユーザーが `ack-fixed` で修正完了確認 | `resolved` |
| ユーザーが除外指示 | `wont_fix` |

`pr-review` から返却される `finding-thread-map.json` には各 finding の投稿成否が含まれる。成否が不明な場合（`finding-thread-map.json` 不在時）は全 finding を `pr_thread_id: null` / `post_failed: false` とする。

### 8.5-6: サマリー作成 → ファイル出力 → PR 投稿（必須・処理順序厳守）

PR サマリースレッドの投稿は、以下の順序で実施する。**ファイルと PR コメントの内容は完全同一** とする。

```
1. サマリー本文を構築（特殊文字エスケープ適用済みの最終形）
2. review-summary.md としてレビュー実施フォルダに Write で保存
3. 保存した review-summary.md を --rawfile / @file で PR サマリースレッドに投稿
```

#### 手順詳細

**手順 1: サマリー本文の構築**

`${CLAUDE_SKILL_DIR}/references/template/output/review-summary.md` のフォーマットに従い、Step 5-7 の結果からサマリー本文を構築する。Markdown 特殊文字のエスケープ（`\#` `\@` `\!` 等）もこの時点で適用する。

**手順 2: review-summary.md へのファイル出力**

構築した本文を `Write` ツールでレビュー実施フォルダに保存する:

```
.claude/.local/plugins/deep-code-review/{branch_name}/{yyyyMMdd_HHmmss}/review-summary.md
```

state.yaml と同じタイムスタンプフォルダに配置する。

**手順 3: PR サマリースレッドへの投稿**

保存済みの `review-summary.md` をそのまま PR コメント本文として投稿する。bash heredoc ではなく **ファイルベースで jq に渡す**:

```bash
# review-summary.md を --rawfile で読み込み JSON body を構築
jq -n --rawfile body "<timestamp>/review-summary.md" \
  '{comments:[{parentCommentId:0,content:$body,commentType:1}],status:"active"}'
```

PowerShell の場合は `@file` 形式:

```powershell
jq -n --rawfile body "<timestamp>/review-summary.md" '...' |
  Out-File -LiteralPath $jsonFile -Encoding utf8NoBOM
curl.exe ... -d "@$jsonFile" "<API URL>"
```

これにより Markdown 特殊文字（`#` `|` `_` `\` 等）が bash/PowerShell のシェル処理で破壊されることを防ぐ。

#### インラインコメントの投稿手順

各 finding のインラインコメントも同一のファイルベースパターンで投稿する。
サマリースレッドの構成・インラインコメントの本文フォーマット・Finding ID 表示ルールは `pr-review/references/comment-posting.md` に従う。

**手順（finding ごとに繰り返し）**:

1. コメント本文を構築（特殊文字エスケープ適用済み）し、一時ファイルに保存
2. `jq --rawfile`（本文）+ `--arg`（パス・行番号）で JSON body を構築し、ファイルに出力
3. `curl @file` で API 投稿
4. レスポンスから `thread_id` を取得し、state.yaml の該当 finding に記録

インラインコメントの本文ファイルは一時ファイルとして扱い、投稿後に削除する（永続保存不要）。
永続保存するのは **review-summary.md（サマリースレッド）のみ**。

**PowerShell 実装例（TFS）**:

```powershell
# 1. コメント本文をファイルに保存（Write ツール経由で作成済み想定）
$bodyFile = "<session>/workspace/comment_CR-001.md"

# 2. ファイルパスをファイルに保存（// プレフィクスで MSYS 回避）
$pathFile = New-TemporaryFile
"//$($filePath.TrimStart('/'))" | Out-File -LiteralPath $pathFile -Encoding utf8NoBOM

# 3. jq で JSON 構築 → ファイル出力
$jsonFile = New-TemporaryFile
& jq -n --rawfile content $bodyFile --rawfile path $pathFile `
  --argjson sl $startLine --argjson el $endLine `
  '{comments:[{parentCommentId:0,content:$content,commentType:1}],status:"active",threadContext:{filePath:($path|sub("^//";"/")),rightFileStart:{line:$sl,offset:1},rightFileEnd:{line:$el,offset:1}}}' |
  Out-File -LiteralPath $jsonFile -Encoding utf8NoBOM
# 注意: pullRequestThreadContext は省略する（TFS が自動で適切な iteration を解決する）
# firstComparingIteration:1, secondComparingIteration:1 を指定すると
# iteration 1 同士の比較（差分なし）となりインラインコード表示がローディングのまま停止する

# 4. curl @file で投稿
$http = & curl.exe -sS --max-time 30 --ntlm --netrc-file $netrc `
  -o $resp -w '%{http_code}' -X POST -H "Content-Type: application/json" `
  -d "@$jsonFile" "<API URL>/threads?api-version=5.0"

# 5. thread_id 取得
$tid = (Get-Content $resp -Raw | ConvertFrom-Json).id
```

**投稿順序**: インラインコメントを全件投稿 → 旧サマリースレッドを `status=closed` → 新サマリースレッドを投稿（`comment-posting.md` セクション 7.5.0）。

### 8.5-7: 検証

- [ ] state.yaml が valid YAML
- [ ] `findings` の全エントリに `detail_summary` が記述されている
- [ ] PR レビュー時、投稿済みの全 finding に `pr_thread_id` が記録されている
- [ ] `review_round` が前回 +1 で正しい
- [ ] `remaining_issues` と `resolved_since_last` に矛盾がない（同一 ID が両方に存在しない）

詳細は `${CLAUDE_SKILL_DIR}/references/state/state-management.md` を参照。

---

> 前フェーズ: [flow-steps-review.md](flow-steps-review.md)（Step 4〜7） / [flow-steps-early.md](flow-steps-early.md)（Step 0-P〜3.5） / 索引・全体図: [flow.md](flow.md)
