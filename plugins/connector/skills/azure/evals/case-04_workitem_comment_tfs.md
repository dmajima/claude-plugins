# Case 04: TFS 作業項目へのコメント投稿（render-check FAIL → HTML 変換 → JSON Patch）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://tfs.example.local/tfs/DefaultCollection/WebApp/_workitems/edit/456 に調査結果をコメントして"（下書きは会話中に提示済みで、Markdown の見出し `## 調査結果`・太字 `**原因**`・コードフェンスを含む） |
| 引数 | 作業項目 URL（コレクション `DefaultCollection` / プロジェクト `WebApp` / 作業項目 ID `456`）+ Markdown 下書き |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` の `tfs-password` エントリに `domains: ["tfs.example.local"]` が登録済み / 作業項目 456 が存在する |

## 期待動作

### Phase 1: 認証事前確認とホスト判定

- `tfs-password` エントリの存在を確認し、ホスト `tfs.example.local` は `domains[]` に登録済み → 種別 = オンプレ TFS / `curl --ntlm --netrc-file` / api-version = 6.0 と判定する
- URL 解析: ベース URL `https://tfs.example.local/tfs/DefaultCollection` / プロジェクト `WebApp` / 作業項目 ID `456`
- 投稿先が **TFS の作業項目コメント** のため、render-check ターゲット = `ado-workitem-html` を確定する（PR 系の `ado-markdown` ではない）

### Phase 2: 対象確認

- `GET https://tfs.example.local/tfs/DefaultCollection/WebApp/_apis/wit/workitems/456?api-version=6.0` で `fields["System.Title"]` を取得する（ID 打ち間違いによる誤投稿防止。承認時に提示する）

### Phase 3: render-check ゲート（FAIL → HTML 変換）

- 下書き + ターゲット `ado-workitem-html` で `render-check` スキルを実行する
- `## 調査結果`（見出し）・`**原因**`（太字）・コードフェンスが Markdown 構文として検出され、総合判定 **FAIL** が返る（TFS の `System.History` は Markdown を解釈せず、`## 見出し` 等はそのまま文字表示される）
- azure-devops-markdown.md セクション 5 の変換表に基づく HTML 変換案を提示する: `## 調査結果` → `<b>調査結果</b>` / `**原因**` → `<b>原因</b>` / コードフェンス → `<pre>` ... `</pre>` / 改行 → `<br>`
- `AskUserQuestion` で変換案の採用を確認 → ユーザーが採用 → 修正後本文（HTML）で再チェック → **PASS** が返る

### Phase 4: 承認

- 作業項目 456（System.Title 併記）・操作内容（コメント投稿）・確定 HTML 本文を提示し、`AskUserQuestion` で承認を得る
- ユーザーが承認を選択する（未承認のまま PATCH しない）

### Phase 5: 実行と結果検証

- body は `jq -n --rawfile html "$CONTENT_FILE" '[ { op: "add", path: "/fields/System.History", value: $html } ]'` で JSON Patch として構築する（mktemp + chmod 600 + trap）
- `PATCH https://tfs.example.local/tfs/DefaultCollection/WebApp/_apis/wit/workitems/456?api-version=6.0` を `Content-Type: application/json-patch+json` + `curl --ntlm --netrc-file "$NETRC" --max-time 30` で発行する（TFS には comments API が安定提供されないため `System.History` への add で投稿する。add はコメント追加であり、フィールド上書きではない）
- レスポンスの `rev` が投稿前より増加していることを確認し、作業項目 URL `https://tfs.example.local/tfs/DefaultCollection/WebApp/_workitems/edit/456` とともに投稿成功を報告する
- `System.History` 以外のフィールド（State / AssignedTo / タイトル等）の変更を JSON Patch に混在させない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（作業項目 456 のディスカッションにコメントが 1 件追加される。ローカル一時ファイルは削除済み） |
| 標準出力（要約） | render-check 結果（FAIL）→ HTML 変換案の提示と採用確認 → 再チェック（PASS）→ 承認質問 → 投稿完了報告（作業項目 URL 付き） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは 投稿先 = TFS の作業項目コメント（`System.History` は HTML レンダリングで Markdown 非解釈）である。これにより render-check ターゲットが `ado-workitem-html` になって Markdown 下書きが FAIL し、API も comments API ではなく JSON Patch（`PATCH workitems/{id}` への `System.History` add）になる。クラウドの作業項目コメントであれば `ado-markdown` + comments API（`POST .../workItems/{id}/comments?api-version=7.1-preview.4` を `az rest` で発行）となり、Markdown のまま投稿できる。

## 関連ケース

- `case-01_pr_create_tfs.md`（同じ TFS ホストでも PR 系の本文は Markdown レンダリングのため `ado-markdown` で検証する対比）
- `case-02_pr_comment_cloud.md`（クラウド経路。作業項目コメントもクラウドなら Markdown のまま投稿できる対比）
