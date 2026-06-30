# Backlog 読み取り API（詳細実装）

`backlog` スキル Step 3（読み取り系）の詳細実装。共通の安全原則は [safe-api-access.md](../../../references/safe-api-access.md)、認証確認は [credentials-precheck.md](../../../references/credentials-precheck.md) を参照。

## 共通事項

- ベース URL: `https://{space-host}/api/v2`（`{space-host}` 例: `example.backlog.jp`）
- 認証: API キーをクエリパラメータ `apiKey` で付与する
- API キーの取得（credentials.json から domains 照合で特定）:

```bash
APIKEY=$(jq -r --arg host "$SPACE_HOST" \
  '.credentials | to_entries[] | select(.value.domains[]? == $host) | .value.value' \
  "$HOME/.claude/credentials.json" | head -n 1)
[ -n "$APIKEY" ] || { echo "認証情報なし: $SPACE_HOST"; exit 1; }
```

- **プロセス一覧への露出対策**: URL に `apiKey` を含める場合は curl の `--config` ファイル経由で渡す（下記パターン）。`--config` ファイルには `url` 行のみを記載し、メソッド・データ・出力フォーマットは CLI 側で渡す（二重指定回避）
- **アーキテクチャ上の制約**: Backlog API v2 の API キー認証はクエリパラメータ方式のみ（ヘッダ方式は提供されない。OAuth 2.0 は別フローのため本スキルのスコープ外）。クエリ中のキーは **Backlog 側のサーバーログに記録されうる**（回避不能）。漏洩が疑われる場合は Backlog の個人設定からキーを再発行（ローテーション）する
- **会話出力のマスク**: コマンド・URL を会話出力へ転記する際は `apiKey=` 以降を `apiKey=***REDACTED***` に **完全置換** する（末尾文字も残さない）
- **デバッグ禁止**: Backlog 呼び出しに `-L`（リダイレクト自動追従）/ `-v` / `--trace` 系を付けない。3xx が返った場合は異常として停止する（Backlog API は通常リダイレクトしない）

```bash
# 共通呼び出しパターン（GET）
CURLCFG=""; RESP=""
cleanup() { rm -f "${CURLCFG:-}" "${RESP:-}" 2>/dev/null || true; unset APIKEY; }
trap cleanup EXIT INT TERM HUP QUIT
CURLCFG=$(mktemp); chmod 600 "$CURLCFG"
RESP=$(mktemp); chmod 600 "$RESP"
printf 'url = "https://%s/api/v2/%s?apiKey=%s%s"\n' "$SPACE_HOST" "$API_PATH" "$APIKEY" "$EXTRA_QUERY" > "$CURLCFG"
HTTP_CODE=$(curl -sS --max-time 30 -H "Accept: application/json" \
  --config "$CURLCFG" -o "$RESP" -w '%{http_code}')
# HTTP_CODE の分岐は safe-api-access.md セクション 5 に従う
```

- クエリ値（keyword 等）は URL エンコード必須。`jq -rn --arg v "$VALUE" '$v|@uri'` でエンコードして `$EXTRA_QUERY` に連結する

## 操作一覧

### 1. プロジェクト情報の取得（textFormattingRule 判定）

```text
GET /api/v2/projects/{projectIdOrKey}
```

- レスポンス主要フィールド: `id`（数値）・`projectKey`・`name`・`textFormattingRule`（`"backlog"` / `"markdown"`）
- 書き込み前の記法判定と、課題検索の `projectId[]`（数値）解決に使用する

### 2. 課題検索

```text
GET /api/v2/issues?projectId[]={id}&keyword={kw}&count=20&sort=updated&order=desc
```

| パラメータ | 内容 |
|-----------|------|
| `projectId[]` | プロジェクト ID（数値）。プロジェクトキーから操作 1 で解決 |
| `keyword` | 全文検索キーワード（URL エンコード必須） |
| `statusId[]` / `assigneeId[]` / `categoryId[]` | 絞り込み（ID は操作 5 / 6 で解決） |
| `count` | 取得件数（既定 20、最大 100） |
| `sort` / `order` | `updated` / `desc` を既定とする |

### 3. 課題取得

```text
GET /api/v2/issues/{issueIdOrKey}
```

- `issueIdOrKey` には課題キー（`PROJ-123`）がそのまま使える
- 主要フィールド: `issueKey`・`summary`・`description`・`status.name`・`assignee.name`・`priority.name`・`dueDate`・`updated`

### 4. コメント取得

```text
GET /api/v2/issues/{issueIdOrKey}/comments?order=desc&count=20
```

- `content` が null のコメントはステータス変更等の変更ログ（`changeLog` 配列に変更内容）
- さらに過去のコメントは `maxId` でページングする

### 5. ステータス一覧（ID 解決用）

```text
GET /api/v2/projects/{projectIdOrKey}/statuses
```

- `id` / `name` の対応表を取得（プロジェクトごとにカスタムステータスあり）
- ステータス名 → `statusId` の解決に使用。名前が曖昧な場合は候補をユーザーに提示する

### 6. プロジェクトユーザー一覧（担当者 ID 解決用）

```text
GET /api/v2/projects/{projectIdOrKey}/users
```

- `id` / `name` / `mailAddress` を取得。担当者名 → `assigneeId` の解決に使用
- 同姓同名・部分一致が複数ある場合は候補をユーザーに提示する

### 7. 優先度一覧

```text
GET /api/v2/priorities
```

- 既定: 2=高 / 3=中 / 4=低（スペース共通）

## 結果報告の整形

- 課題: `課題キー / 件名 / ステータス / 担当者 / 期限 / 更新日時` + 本文要約 + 課題 URL（`https://{space-host}/view/{issueKey}`）
- 検索結果: 上記を一覧表で提示し、件数と絞り込み条件を明記する
- コメント: 投稿者 / 日時 / 本文（変更ログは変更内容を要約）
- レスポンスの生 JSON をそのまま貼らない（要点を整形する）

## エラー時の補足（Backlog 固有）

- `404`: 課題キー誤り・アクセス権限なし（Backlog は権限なしも 404 を返す場合がある）
- `429`: レート制限。`X-RateLimit-Reset` ヘッダを確認しバックオフ（[safe-api-access.md](../../../references/safe-api-access.md) セクション 5）
- `401`: API キー無効。credentials.json の値の再確認をユーザーに依頼（リトライ禁止）
