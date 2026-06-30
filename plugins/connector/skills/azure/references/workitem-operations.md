# 作業項目操作 API（詳細実装）

`azure` スキルの作業項目（Work Item）操作の詳細実装。書き込み操作の **実行前提**: render-check 通過 + `AskUserQuestion` でのユーザー承認済みであること。

共通の安全原則は [safe-api-access.md](../../../references/safe-api-access.md)、ホスト判定は [host-detection.md](host-detection.md) を参照。

## 1. 作業項目取得（操作前の確認用）

```text
GET {base}/{project}/_apis/wit/workitems/{id}?api-version={v}
```

- 主要フィールド: `fields["System.Title"]` / `["System.State"]` / `["System.AssignedTo"]` / `["System.WorkItemType"]`
- コメント投稿前に対象の存在とタイトルを確認し、承認時にユーザーへ提示する（ID の打ち間違いによる誤投稿防止）

## 2. 作業項目へのコメント投稿

**クラウドと TFS で API もレンダリング方式も異なる**。ホスト種別判定の結果に従って分岐する。

### クラウド（comments API / Markdown）

```text
POST {base}/{project}/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4
Content-Type: application/json
body: { "text": <本文> }
```

- render-check ターゲット: `ado-markdown`
- `az` CLI に専用コマンドがないため `az rest` を使用する:

```bash
az rest --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --method POST \
  --url "{base}/{project}/_apis/wit/workItems/{id}/comments?api-version=7.1-preview.4" \
  --headers "Content-Type=application/json" \
  --body @"$BODY"
```

### TFS（System.History / HTML）

TFS（Azure DevOps Server）には comments API が安定提供されないため、**JSON Patch による `System.History` への追記** で投稿する。`System.History` への add は「ディスカッションへのコメント追加」として扱われる（フィールド上書きではない）。

```text
PATCH {base}/{project}/_apis/wit/workitems/{id}?api-version=6.0
Content-Type: application/json-patch+json
body: [ { "op": "add", "path": "/fields/System.History", "value": <HTML 本文> } ]
```

```bash
jq -n --rawfile html "$CONTENT_FILE" \
  '[ { op: "add", path: "/fields/System.History", value: $html } ]' > "$BODY"

HTTP_CODE=$(curl -sS --max-time 30 --ntlm --netrc-file "$NETRC" \
  -H "Accept: application/json" -H "Content-Type: application/json-patch+json" \
  -X PATCH --data-binary @"$BODY" \
  -o "$RESP" -w '%{http_code}' \
  "{base}/{project}/_apis/wit/workitems/{id}?api-version=6.0" || echo "000")
```

- render-check ターゲット: `ado-workitem-html`（**Markdown は解釈されない**。`## 見出し` や ``` フェンスはそのまま文字表示される）
- Markdown で下書きされた本文は render-check が HTML 変換案（[azure-devops-markdown.md](../../../references/rendering/azure-devops-markdown.md) セクション 5 の変換表）を提示するので、確定本文（HTML または平文）を投稿する

## 3. 結果検証・報告

| 操作 | 検証 | 報告 |
|-----|------|------|
| クラウド comments API | レスポンスの `id`（コメント ID）が返ること | 作業項目 URL + コメント投稿成功 |
| TFS System.History | レスポンスの `rev` が増加していること | 作業項目 URL（`{base}/{project}/_workitems/edit/{id}`）+ 投稿成功 |

- 期待と異なるレスポンス（rev 不変・エラー JSON）の場合は直ちにユーザーへ報告する

## 4. 禁止事項（作業項目固有）

- コメント投稿以外のフィールド変更（State・AssignedTo・タイトル等）を「ついでに」行わない（ユーザーが明示的に依頼した場合のみ、変更前 → 変更後を提示して承認の上で実行）
- `System.History` 以外のフィールドへの JSON Patch をコメント投稿操作に混在させない
- 複数作業項目への一括コメント投稿（ユーザーの明示指示 + 対象一覧の承認がある場合を除く）
