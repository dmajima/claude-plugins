# Backlog 書き込み API（詳細実装）

`backlog` スキル Step 4（書き込み系）の詳細実装。**実行前提**: render-check 通過（FAIL なし）+ `AskUserQuestion` でのユーザー承認済みであること（SKILL.md Step 4）。

共通の呼び出しパターン（`--config` 経由の apiKey 渡し・一時ファイル管理・HTTP エラー分岐）は [api-read.md](api-read.md) の「共通事項」と [safe-api-access.md](../../../references/safe-api-access.md) に従う。

## 1. コメント投稿

```text
POST /api/v2/issues/{issueIdOrKey}/comments
Content-Type: application/x-www-form-urlencoded
```

| パラメータ | 必須 | 内容 |
|-----------|------|------|
| `content` | 必須 | コメント本文（render-check 通過済みの確定本文） |
| `notifiedUserId[]` | 任意 | 通知先ユーザー ID（ユーザーが通知先を明示した場合のみ） |

本文は一時ファイル経由で渡す（特殊文字・複数行を安全に扱うため）:

```bash
CONTENT_FILE=$(mktemp); chmod 600 "$CONTENT_FILE"
# render-check 通過済みの確定本文を書き込んでおく
printf '%s' "$CONFIRMED_CONTENT" > "$CONTENT_FILE"

CURLCFG=$(mktemp); chmod 600 "$CURLCFG"
printf 'url = "https://%s/api/v2/issues/%s/comments?apiKey=%s"\n' "$SPACE_HOST" "$ISSUE_KEY" "$APIKEY" > "$CURLCFG"
HTTP_CODE=$(curl -sS --max-time 30 -X POST --config "$CURLCFG" \
  --data-urlencode "content@${CONTENT_FILE}" \
  -o "$RESP" -w '%{http_code}')
```

- `--data-urlencode "content@file"` でファイル内容を URL エンコードして送信する（シェル変数の直接埋め込み禁止）
- 成功時レスポンスの `id` からコメント URL を組み立てる: `https://{space-host}/view/{issueKey}#comment-{id}`

## 2. 課題メタ情報の更新

```text
PATCH /api/v2/issues/{issueIdOrKey}
Content-Type: application/x-www-form-urlencoded
```

| パラメータ | 内容 | ID 解決 |
|-----------|------|---------|
| `statusId` | ステータス変更 | [api-read.md](api-read.md) 操作 5（ステータス一覧） |
| `assigneeId` | 担当者変更 | 操作 6（プロジェクトユーザー一覧）。未割当にする場合は空文字 |
| `priorityId` | 優先度変更 | 操作 7（優先度一覧） |
| `resolutionId` | 完了理由（0=対応済み / 1=対応しない / 2=無効 / 3=重複 / 4=再現しない） | 固定値 |
| `summary` / `description` | 件名・本文の更新 | `description` は render-check 必須 |
| `dueDate` | 期限（`yyyy-MM-dd`） | — |
| `comment` | 更新と同時に付けるコメント | render-check 必須 |

```bash
HTTP_CODE=$(curl -sS --max-time 30 -X PATCH --config "$CURLCFG" \
  --data-urlencode "statusId=${STATUS_ID}" \
  --data-urlencode "comment@${CONTENT_FILE}" \
  -o "$RESP" -w '%{http_code}')
```

### 更新時の必須手順

1. **変更前の値を取得**（課題取得 API）し、「変更前 → 変更後」をユーザーへ提示してから承認を得る
2. 指定されたフィールド **のみ** をパラメータに含める（指定外フィールドを送らない）
3. ステータス名・担当者名が曖昧（部分一致複数・該当なし）の場合は、一覧から候補を提示して確定する

## 3. render-check との連携

| 更新対象 | render-check | ターゲット |
|---------|--------------|-----------|
| `content`（コメント）/ `comment` / `description` | **必須** | textFormattingRule に応じて `backlog-notation` / `backlog-markdown` |
| `summary`（件名） | 簡易（SECRET / SIZE のみ。件名は装飾されないため） | — |
| `statusId` / `assigneeId` 等の ID 系のみ | 不要（本文なし）。承認は必須 | — |

## 4. 結果検証・報告

- コメント投稿: レスポンス `id` を確認し、コメント URL を報告する
- 課題更新: レスポンスの `status.name` / `assignee.name` 等が期待値と一致することを確認し、変更内容と課題 URL を報告する
- レスポンスが期待と異なる場合（別フィールドが変わった等）は直ちにユーザーへ報告する（黙って追加修正しない）

## 5. 禁止事項（書き込み固有）

- render-check 未通過本文・未承認操作の実行
- 依頼されていない課題への書き込み・依頼外フィールドの変更
- 複数課題の一括更新（ユーザーの明示指示 + 対象課題一覧の承認がある場合を除く）
- 失敗時の安易な再投稿（重複コメントの原因。HTTP コード分岐に従い、再試行はユーザー確認後）
