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

### 8. 共有ファイル一覧取得 / ファイル情報取得

```text
GET /api/v2/projects/{projectIdOrKey}/files/metadata/{path}
```

| パラメータ | 種別 | 内容 |
|-----------|------|------|
| `projectIdOrKey` | パス | プロジェクト ID（数値）またはプロジェクトキー |
| `path` | パス | ファイルまたはディレクトリのパス（URL エンコード必須）。ルートディレクトリは空文字列 |
| `order` | クエリ | `asc` / `desc`（既定: `desc`） |
| `offset` | クエリ | ページネーションオフセット |
| `count` | クエリ | 取得件数（1〜100、既定: 20） |

- `{path}` には **ディレクトリパスのみ** を指定する。ファイルパスを直接指定すると 400 エラーになる（Backlog API の仕様）
- ディレクトリを指定した場合: 直下のファイル・サブディレクトリの一覧を返す（子孫は含まない）
- ファイルの情報を取得したい場合: **親ディレクトリ** のパスで呼び出し、レスポンス配列からファイル名で抽出する（後述「ファイル指定 URL の処理」参照）
- 件数が多い場合は `count=100` + `offset` でページングする

**レスポンス主要フィールド（各要素）:**

| フィールド | 型 | 内容 |
|-----------|---|------|
| `id` | 数値 | 共有ファイル / フォルダの一意 ID |
| `projectId` | 数値 | プロジェクト ID |
| `type` | 文字列 | `"file"` または `"directory"` |
| `dir` | 文字列 | 親ディレクトリのパス |
| `name` | 文字列 | ファイル / フォルダ名 |
| `size` | 数値 / null | ファイルサイズ（バイト）。ディレクトリは null |
| `createdUser` | オブジェクト | 作成者（`id` / `name` 等） |
| `created` | 文字列 | 作成日時（ISO 8601） |
| `updatedUser` | オブジェクト / null | 更新者 |
| `updated` | 文字列 | 更新日時（ISO 8601） |

#### URL パターンとパース手順

Backlog のファイル機能 URL は 2 パターンある。いずれもスペースホスト（`.backlog.jp` / `.backlog.com`）を含む。

**パターン A: ダイレクトパス URL**

```
https://{space-host}/file/{projectKey}/{encoded-path}
```

- `{projectKey}`: プロジェクトキー（URL の `/file/` 直後のセグメント）
- `{encoded-path}`: URL エンコード済みのパス。末尾 `/` はディレクトリ、末尾がファイル名ならファイル

パース手順:

```bash
# URL からスペースホスト・プロジェクトキー・パスを抽出
SPACE_HOST=$(echo "$URL" | sed -n 's|^https://\([^/]*\)/file/.*|\1|p')
PROJECT_KEY=$(echo "$URL" | sed -n 's|^https://[^/]*/file/\([^/]*\)/.*|\1|p')
# プロジェクトキー以降のパス部分（URL エンコード済みのまま取得し、クエリ/フラグメントを除去）
FILE_PATH=$(echo "$URL" | sed -n 's|^https://[^/]*/file/[^/]*/\(.*\)|\1|p' | sed 's|[?#].*||')
```

**入力値の検証**: URL からパースした `SPACE_HOST` / `PROJECT_KEY` / `FILE_PATH` を `--config` に埋め込む前に、改行・制御文字を含まないことを確認する（[safe-api-access.md](../../../references/safe-api-access.md) のインジェクションガードと同水準）。

**ディレクトリ URL（末尾 `/`）の場合:**

```bash
# パスをそのまま使用（末尾 / 付き）
printf 'url = "https://%s/api/v2/projects/%s/files/metadata/%s?apiKey=%s&count=100"\n' \
  "$SPACE_HOST" "$PROJECT_KEY" "$FILE_PATH" "$APIKEY" > "$CURLCFG"
HTTP_CODE=$(curl -sS --max-time 30 -H "Accept: application/json" \
  --config "$CURLCFG" -o "$RESP" -w '%{http_code}')
```

**ファイル URL（末尾がファイル名）の場合:**

`files/metadata` はファイルパスを直接受け付けない（400 エラー）。親ディレクトリの一覧から該当ファイルを抽出する。

```bash
# 親ディレクトリパスを取得（最後の / までの部分）
# ルート直下ファイル（/ を含まない）の場合は空文字列（= ルートディレクトリ）にする
if echo "$FILE_PATH" | grep -q '/'; then
  PARENT_DIR=$(echo "$FILE_PATH" | sed 's|/[^/]*$|/|')
else
  PARENT_DIR=""
fi
printf 'url = "https://%s/api/v2/projects/%s/files/metadata/%s?apiKey=%s&count=100"\n' \
  "$SPACE_HOST" "$PROJECT_KEY" "$PARENT_DIR" "$APIKEY" > "$CURLCFG"
HTTP_CODE=$(curl -sS --max-time 30 -H "Accept: application/json" \
  --config "$CURLCFG" -o "$RESP" -w '%{http_code}')
# レスポンス配列からファイル名で抽出（name フィールドはデコード済み）
# jq '.[] | select(.name == "<デコード済みファイル名>")' "$RESP"
```

**パターン B: エイリアス URL**

```
https://{space-host}/alias/file/{sharedFileId}
```

- `{sharedFileId}`: 共有ファイル / フォルダの数値 ID

エイリアス URL は API エンドポイントではなく、Web 認証（ブラウザセッション）でのみ解決される。API キーでは解決できない（認証なしリダイレクトはログインページへ向かう）。

パース手順:

```bash
# エイリアス URL からスペースホスト・ファイル ID を抽出
SPACE_HOST=$(echo "$URL" | sed -n 's|^https://\([^/]*\)/alias/file/.*|\1|p')
SHARED_FILE_ID=$(echo "$URL" | sed -n 's|^https://[^/]*/alias/file/\([0-9]*\).*|\1|p')
```

**エイリアス解決手順:**

1. **プロジェクトキーの取得**: エイリアス URL にはプロジェクト情報が含まれないため、ユーザーにプロジェクトキーを `AskUserQuestion` で確認する（会話文脈やダイレクトパス URL からプロジェクトキーが既知の場合は省略可）

2. **ファイル / フォルダの判別と情報取得**: プロジェクトキーが判明したら、まず download API でファイルとしてアクセスを試みる。404 ならフォルダとしてツリー走査する

**ファイルエイリアスの場合** — download API でヘッダからメタデータを取得:

```bash
# $HEADERS も mktemp + trap 対象にする（共通パターン準拠）
HEADERS=$(mktemp); chmod 600 "$HEADERS"
# cleanup() に $HEADERS を追加: cleanup() { rm -f "${CURLCFG:-}" "${RESP:-}" "${HEADERS:-}" ... }

# GET /files/{id} でレスポンスヘッダからファイル名・サイズ・種別を取得
# ボディは /dev/null に破棄（メタデータ取得目的）
printf 'url = "https://%s/api/v2/projects/%s/files/%s?apiKey=%s"\n' \
  "$SPACE_HOST" "$PROJECT_KEY" "$SHARED_FILE_ID" "$APIKEY" > "$CURLCFG"
HTTP_CODE=$(curl -sS --max-time 30 \
  --config "$CURLCFG" -D "$HEADERS" -o /dev/null -w '%{http_code}')
# Content-Disposition: attachment; filename*=UTF-8''<URL エンコード済みファイル名>
# Content-Type: application/pdf 等
# Content-Length: <バイト数>
```

- HTTP 200: ファイルとして存在。ヘッダからファイル名（`Content-Disposition`）・サイズ（`Content-Length`）・種別（`Content-Type`）を取得する
- HTTP 404: 該当 ID のファイルが存在しない、またはアクセス権限なし
- ボディは全量ダウンロードされるが `-o /dev/null` で破棄する（メタデータ取得が目的）
- HEAD メソッドは Backlog API で 405 を返すため使用しない

**フォルダエイリアスの場合** — ファイルツリー内の ID 検索:

```bash
# download API はフォルダに対しても 404 を返すため、ツリー走査で ID を探す
# ルートから段階的に /files/metadata/ を呼び出し、レスポンスの id フィールドを照合
# 一致する id が見つかったらそのディレクトリの一覧（またはメタデータ）を返す
```

- ルートから深さ優先でディレクトリを走査し、各階層の一覧で `id` が一致するエントリを探す
- 一致したエントリが `type: "directory"` の場合: そのパスで `files/metadata` を呼び出して内容一覧を取得する
- API 呼び出し回数を抑えるため、ユーザーにおおよそのパス（「議事録フォルダの中」等）がわかる場合はそこから探索を開始する
- ツリー走査でも見つからない場合は、ダイレクトパス URL の提供を依頼する

**エイリアス解決の注意事項:**

- エイリアス Web URL に API キーを **付与してはならない**（リダイレクト先 URL にキーが露出する）
- エイリアス URL が `/alias/file/{id}` 形式であることを確認してから解決を試みる
- ファイルかフォルダかが不明な場合は、まず download API（ファイル向け）を試し、404 ならフォルダとしてツリー走査する

## 結果報告の整形

- 課題: `課題キー / 件名 / ステータス / 担当者 / 期限 / 更新日時` + 本文要約 + 課題 URL（`https://{space-host}/view/{issueKey}`）
- 検索結果: 上記を一覧表で提示し、件数と絞り込み条件を明記する
- コメント: 投稿者 / 日時 / 本文（変更ログは変更内容を要約）
- 共有ファイル一覧: 一覧表（`名前 / 種別 / サイズ / 更新日時`）で提示。`type` が `directory` の場合は `[フォルダ]` と表記し、サイズは `-`。ファイルサイズは KB/MB 単位に変換。ファイル URL（`https://{space-host}/file/{projectKey}/{path}`）を添える
- レスポンスの生 JSON をそのまま貼らない（要点を整形する）

## エラー時の補足（Backlog 固有）

- `404`: 課題キー誤り・アクセス権限なし（Backlog は権限なしも 404 を返す場合がある）
- `429`: レート制限。`X-RateLimit-Reset` ヘッダを確認しバックオフ（[safe-api-access.md](../../../references/safe-api-access.md) セクション 5）
- `401`: API キー無効。credentials.json の値の再確認をユーザーに依頼（リトライ禁止）
