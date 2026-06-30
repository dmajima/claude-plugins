# Case 03: PR 承認（vote=10。render-check 省略・vote 値明示の承認必須）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123 を承認して" |
| 引数 | PR URL（組織 `contoso` / プロジェクト `WebApp` / リポジトリ `webapp` / PR ID `123`） |
| フラグ | なし（対話モード） |
| 既存状態 | `az` CLI インストール済みかつ `az account show` が終了コード 0 を返す（ログイン済み） / PR 123 は active |

## 期待動作

### Phase 1: 認証事前確認とホスト判定

- `az account show` の終了コード 0 で認証済みを確認する
- ホストが `dev.azure.com` → 種別 = クラウド / 操作手段 = `az` CLI / api-version = 7.1 と判定する

### Phase 2: 操作種別判定（render-check 省略）

- 「PR 承認（vote）」を **書き込み（本文なし）** と判定する（SKILL.md Step 2 の表）
- 投稿本文が存在しないため render-check ゲートは省略する。ただし `AskUserQuestion` での承認は省略しない

### Phase 3: 対象確認

- `az repos pr show --id 123 --org https://dev.azure.com/contoso --output json` で `title` と `status`（active）を取得し、承認時の提示内容に含める（PR の取り違え防止）

### Phase 4: vote 値を明示した承認

- vote はユーザー本人の意思表示の代行であるため、「PR 123（タイトル併記）に vote=10（承認 / Approved）を設定する」ことを明示して `AskUserQuestion` で確認する（選択肢例: 承認 10 / 提案付き承認 5 / 中止）
- vote 値の明示なしに PUT を発行しない。ユーザーが「承認 10」を選択する

### Phase 5: reviewer ID 取得と vote 設定

- 自分（認証ユーザー）の ID を取得する: `az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 --url "https://dev.azure.com/contoso/_apis/connectionData" --query authenticatedUser.id -o tsv`
- `PUT https://dev.azure.com/contoso/WebApp/_apis/git/repositories/webapp/pullrequests/123/reviewers/{reviewerId}?api-version=7.1` を body `{ "vote": 10 }` で発行する

### Phase 6: 結果検証・報告

- レスポンスの `vote` が 10 と一致することを確認する
- PR URL `https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123` とともに「vote=10（Approved）を設定した」と報告する
- 依頼されていない操作（PR の complete / abandon・コメント投稿）は行わない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（PR 123 のレビュアー vote が 10 に設定される） |
| 標準出力（要約） | 対象 PR と vote 値（10 = Approved）を明示した承認質問 → vote 設定完了報告（PR URL 付き） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 操作種別 = 書き込み（本文なし: vote 設定）である。本文を伴わないため render-check は省略されるが、vote 値と対象 PR を明示した AskUserQuestion 承認は必須のまま残る（SKILL.md Step 2 の表「render-check は省略可、承認は必須」）。

## 関連ケース

- `case-02_pr_comment_cloud.md`（本文ありの書き込み。render-check ゲートが必須になる対比）
- `case-01_pr_create_tfs.md`（TFS の場合の reviewer ID 取得は `GET {base}/_apis/connectionData` を NTLM で呼ぶ）
