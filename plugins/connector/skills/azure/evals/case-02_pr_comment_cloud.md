# Case 02: クラウド PR へのコメント投稿（az devops invoke / api-version 7.1）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123 に「修正対応が完了しました。再レビューをお願いします」とコメントして" |
| 引数 | PR URL（組織 `contoso` / プロジェクト `WebApp` / リポジトリ `webapp` / PR ID `123`）+ 投稿本文 |
| フラグ | なし（対話モード） |
| 既存状態 | `az` CLI インストール済みかつ `az account show` が終了コード 0 を返す（ログイン済み） / PR 123 は active / 本文に自動リンク・メンション・記法不一致・機密情報なし |

## 期待動作

### Phase 1: 認証事前確認とホスト判定

- `az account show` の終了コード 0 で MS アカウント認証済みを確認する
- ホストが `dev.azure.com` → 種別 = クラウド / 操作手段 = `az` CLI / api-version = 7.1 と判定する（NTLM・credentials.json の照合は行わない）
- PR URL を解析し、組織 = `contoso` / プロジェクト = `WebApp` / リポジトリ = `webapp` / PR ID = `123` を確定する

### Phase 2: 操作種別判定

- 「PR コメント投稿」を **書き込み（本文あり）** と判定し、SKILL.md Step 4（書き込み系の実行）へ進む

### Phase 3: render-check ゲート（必須）

- 投稿本文 + ターゲット `ado-markdown` で `render-check` スキルを実行する
- 5 カテゴリ（NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）全てが検査され、総合判定 **PASS** が返る（本文に `#数字` / `!数字` / `@名前` の自動リンク・メンション要素がないため WARN もなし）

### Phase 4: 承認

- 対象 PR（URL・タイトル）・操作内容（新規スレッドとしてコメント投稿）・確定本文を提示し、`AskUserQuestion` で承認を得る
- ユーザーが承認を選択する（未承認のまま投稿しない）

### Phase 5: 実行と結果検証

- body は `jq -n --rawfile content "$CONTENT_FILE" '{ comments: [{ parentCommentId: 0, content: $content, commentType: 1 }], status: "active" }'` で一時ファイル（mktemp + chmod 600 + trap）に構築する
- `az devops invoke --area git --resource pullRequestThreads --route-parameters project=WebApp repositoryId=webapp pullRequestId=123 --org https://dev.azure.com/contoso --api-version 7.1 --http-method POST --in-file "$BODY"` を実行する
- レスポンスにスレッド `id` とコメント `id` が含まれることを確認し、PR URL `https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123` とともに投稿成功を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（PR 123 にコメントスレッドが 1 件作成される。ローカル一時ファイルは削除済み） |
| 標準出力（要約） | render-check 結果（PASS）→ 承認質問 → コメント投稿完了報告（スレッド ID・PR URL 付き） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは ホスト種別 = クラウド（URL のホストが `dev.azure.com`）である。クラウドでは NTLM / credentials.json ではなく `az` CLI（`az devops invoke`）+ api-version 7.1 の経路を使う。

## 関連ケース

- `case-01_pr_create_tfs.md`（ホストがオンプレ TFS の場合。curl --ntlm / api-version 6.0 経路になる対比）
- `case-03_pr_approve.md`（同じクラウド PR への本文なし書き込み。render-check が省略される対比）
- `case-04_workitem_comment_tfs.md`（投稿先が TFS 作業項目の場合。render-check ターゲットが ado-workitem-html になる対比）
