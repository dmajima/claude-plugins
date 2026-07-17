# case-02 クラウド Azure DevOps PR のレビュー（az CLI 経路）

dev.azure.com の PR URL を指定してレビューする正常系ケース。az login 済みの MS アカウント認証を前提に az CLI（az repos pr / az devops invoke）経路を使用する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "https://dev.azure.com/org/project/_git/repo/pullrequest/45 をレビューして"（az login 済み） |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 1 のホスト判定でクラウド Azure DevOps（dev.azure.com / *.visualstudio.com）を検出し、azure-devops-cloud.md の az CLI 経路に分岐する。認証確認は credentials-precheck.md 1.5.1 の `az account show`。

## 期待動作

- URL からホストをクラウド Azure DevOps と判定する
- Step 1.5: `az account show` の終了コードで MS アカウント認証を確認してから API を呼ぶ
- curl --ntlm --netrc-file（オンプレ TFS 用経路）は使用しない
- PAT を使う場合は環境変数 AZURE_DEVOPS_EXT_PAT 経由とし、コマンドライン引数渡し（`-u :$PAT`）はしない（azure-devops-cloud.md セクション 1）
- az repos pr show で PR メタ情報を取得する
- 差分は git fetch + git diff で取得する（Azure DevOps は refs/pull/N/merge を提供しないため。azure-devops-cloud.md セクション 3）
- スレッド一覧・ステータス更新は az devops invoke（pullRequestThreads）経由で行う
- レビュー結果をインラインコメント + サマリースレッドとして PR に投稿する
- state.yaml を `.claude/.local/plugins/deep-code-review/{branch}/` に保存する

## 関連ケース

- case-01: GitHub PR（gh CLI 経路）
- case-06: オンプレ TFS Server（NTLM 経路、対になるホスト分岐）
