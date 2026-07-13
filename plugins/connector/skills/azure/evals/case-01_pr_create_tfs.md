# Case 01: オンプレ TFS への PR 作成（ブランチ確認 → 重複確認 → render-check → 承認 → POST）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "tfs.example.local の WebApp/webapp リポジトリで feature/login から develop への PR を作成して。タイトルは「ログイン機能の追加」、説明はこの下書きで"（説明の下書きは会話中に提示済み） |
| 引数 | ホスト `tfs.example.local` / プロジェクト `WebApp` / リポジトリ `webapp` / ソース `feature/login` / ターゲット `develop` / タイトル + 説明下書き |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` の `tfs-password` エントリに `domains: ["tfs.example.local"]`・`username`・`value` が登録済み / リモートに `feature/login` と `develop` が存在 / 同一ソース → ターゲットの active PR なし / 説明下書きに記法不一致・機密情報なし |

## 期待動作

### Phase 1: 認証事前確認とホスト判定

- `tfs-password` エントリの `username` と `value` が非空であることを `jq` で確認する（値そのものは表示しない）
- ホスト `tfs.example.local` は `dev.azure.com` / `*.visualstudio.com` のいずれでもなく、`tfs-password` の `domains[]` に登録済み → 種別 = オンプレ TFS / 操作手段 = `curl --ntlm --netrc-file` / api-version = 6.0 と判定する
- コレクション未指定のため既定の `DefaultCollection` を採用し、ベース URL を `https://tfs.example.local/tfs/DefaultCollection` に確定する

### Phase 2: 操作種別判定と PR 作成の事前確認

- 「PR 作成」を **書き込み（本文あり）** と判定し、SKILL.md Step 4（書き込み系の実行）へ進む
- ブランチ存在確認: `git ls-remote --heads origin feature/login` / `git ls-remote --heads origin develop` がそれぞれ 1 件を返すことを確認する
- 重複確認: `GET {base}/WebApp/_apis/git/repositories/webapp/pullrequests?searchCriteria.sourceRefName=refs/heads/feature/login&searchCriteria.status=active&api-version=6.0` が 0 件であることを確認する（既存 active PR がある場合は作成せずユーザーに提示する）

### Phase 3: render-check ゲート（必須）

- 説明（description）+ ターゲット `ado-markdown` で `render-check` スキルを実行する
- 5 カテゴリ（NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE）全てが検査され、総合判定 **PASS** が返る
- FAIL が 1 件でもあれば修正案の採用 → 再チェックを繰り返し、解消されるまで投稿に進まない

### Phase 4: 承認

- 対象（コレクション / プロジェクト / リポジトリ）・ソース → ターゲットブランチ・タイトル・確定 description を提示し、`AskUserQuestion` で承認を得る
- ユーザーが承認を選択する（未承認のまま POST しない）

### Phase 5: 実行と結果検証

- NETRC / BODY / RESP は `mktemp` + `chmod 600` + 先張り `trap` で管理する（safe-api-access.md セクション 3。パスワードはコマンドライン引数に渡さない）
- body は `jq -n --arg src "refs/heads/feature/login" --arg tgt "refs/heads/develop" --arg title ... --rawfile desc ...` で構築する（シェル文字列への直接埋め込み禁止）
- `POST https://tfs.example.local/tfs/DefaultCollection/WebApp/_apis/git/repositories/webapp/pullrequests?api-version=6.0` を `curl --ntlm --netrc-file "$NETRC" --max-time 30` で発行する
- HTTP 2xx + レスポンスの `pullRequestId` を確認し、PR URL `https://tfs.example.local/tfs/DefaultCollection/WebApp/_git/webapp/pullrequest/{pullRequestId}` を組み立てて報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（TFS 側に PR が 1 件作成される。ローカル一時ファイルは trap で削除済み） |
| 標準出力（要約） | ブランチ・重複確認の結果 → render-check 結果（PASS）→ 承認質問 → PR 作成完了報告（PR URL・タイトル・ソース → ターゲット付き） |
| 終了状態 | 成功（続けてレビュアー追加・作業項目リンク等が必要かを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは ホスト種別 = オンプレ TFS（`credentials.json` の `tfs-password.domains[]` に登録済みホスト → `curl --ntlm` / api-version 6.0 経路）かつ 操作種別 = PR 作成（書き込み・本文あり → ブランチ存在確認・重複 PR 確認・render-check・AskUserQuestion 承認の全ゲートを通過してから POST）である。

## 関連ケース

- `case-02_pr_comment_cloud.md`（ホストがクラウドの場合。az CLI / api-version 7.1 経路になる対比）
- `case-03_pr_approve.md`（本文なしの書き込み。render-check を省略し承認のみ必須）
- `case-05_unregistered_host.md`（ホストが credentials.json 未登録の場合。API を発行せずユーザー確認・対話取得フォールバックへ分岐）
