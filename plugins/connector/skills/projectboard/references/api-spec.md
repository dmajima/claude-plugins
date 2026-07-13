# HUE ProjectBoard API 仕様（読み取り系 SSOT）

HUE ProjectBoard（Works Applications / Works Human Intelligence のプロジェクト管理 SaaS）の
接続・認証・読み取り API 仕様。**本ファイルが API 仕様の Single Source of Truth**（ADR-9）。
API 変更を検知したら本ファイルを更新する（他ドキュメントへの重複転記をしない）。
書き込み系 API は [api-write.md](api-write.md) を参照。

検証済み環境: テナント `example-tenant` / シート 187 タスク（2026-06-12 実機検証）。

## 1. サービス概要

- ドメイン: `https://{tenant}.pm.apps.worksap.com`
- 基盤: Vue.js SPA + Spring Security バックエンド
- データ配信: REST が主。WebSocket(STOMP over SockJS) は**読み取りには不要だが、書き込みには接続が必須**
  （書き込みボディの connectionId = SockJS session_id をサーバが「生きた接続か」検証する — [api-write.md](api-write.md) セクション 1.2）
- 概念階層: プロジェクト（UUID / URL 上は base62 urlKey）> シート（ページ: DASHBOARD/ISSUE）> WBS ノード（PACKAGE/MILESTONE/TASK）

## 2. 認証（Cookie セッション）

Spring Security フォームログイン。`references/scripts/auth/login.sh` が実装。

| 項目 | 値 |
|------|---|
| エンドポイント | `POST {BASE}/auth/sign-in` |
| Content-Type | `application/x-www-form-urlencoded` |
| パラメータ | `username`（**値はメールアドレス**。`email=` ではない）・`password`・`_csrf`（空可） |
| 事前手順 | `GET {BASE}/auth/sign-in` で初期 SESSION Cookie を取得してから POST |

redirect_url による判定:

| redirect | 判定 |
|---|---|
| `/wbs/projects/quick` を含む | 成功 |
| `error=badCredentials` を含む | 認証失敗 |
| 上記以外 | SSO 等への切替の可能性（フォームログイン不可として明示エラー） |

認証情報は credentials.json の `hue-projectboard` エントリ
（`type=password` / `username`=メール / `value`=パスワード / `auth_method=form:email:password`）。
取得は [credentials-precheck.md](../../../references/credentials-precheck.md) セクション 1 の解決順序で行う
（credentials-manager（導入時）→ credentials.json 直接照合 → 対話取得フォールバック。ハードコード禁止）。

## 3. urlKey ⇔ UUID 変換

URL の `/wbs/project/{urlKey}/...` の urlKey は projectId(UUID) の base62 表現。API は UUID を要求。
`references/scripts/resolve/urlkey.py` が実装（alphabet `a-z A-Z 0-9`、decode→re-encode の自己検証ガード付き — ADR-7）。

アルゴリズム整合ペア（round-trip 検証用）: `wmVbmMRxdCcORy8oUSPGv` ⇔ `0bc4978b-41e7-11f1-9633-85b8872b7139`

## 4. API 呼び出し規約

### 4.1 必須ヘッダ（全 API）

```
Accept: application/json
X-Requested-With: XMLHttpRequest     # 無いと 400 illegalArgs
```

### 4.2 エンドポイント一覧（読み取り）

| API | パス | メソッド | 用途 |
|---|---|---|---|
| getMyTaskProjectCandidates | `/wbs/project/...` | GET | プロジェクト一覧 |
| loadProjectPages | `/wbs/page/loadProjectPages?projectId={UUID}&archiveFilter=ALL` | GET | シート一覧 |
| getPageDetail | `/wbs/page/getPageDetail?projectId={UUID}&pageId={pageId}` | GET | 列定義・statusSet |
| **getWbsNodes** | `/wbs/wbs/node/getWbsNodes?wbsId={sourceId}` | GET | **タスクツリー取得（本命）** |
| getTaskDependenceInformation | `/wbs/wbs/node/...` | GET | 依存情報の読み取り |

> **重要**: node 系は GET=`/wbs/wbs/node`、POST=`/wbs/project/node` で base が異なる。
> getWbsNodes の `wbsId` は loadProjectPages の **sourceId**（pageId ではない）。

### 4.3 SPA フォールバック検知（必須の防御）

パラメータ不足・ルート不在時、サーバは **200 で SPA の HTML** を返す。JSON 期待箇所では
先頭バイトの `<!DOCTYPE` / `<html` を必ず検知する（`with_session.sh` 実装済み）。

### 4.4 エラー早見表

| HTTP / code | 意味 | 対処 |
|---|---|---|
| 401 | 未認証 / セッション切れ | `with_session.sh` が再ログイン + 1 回リトライ |
| 403 | CSRF 不足（POST のみ） | X-XSRF-TOKEN 付与（[api-write.md](api-write.md)） |
| 400 `01010401` illegalArgs | パラメータ / ヘッダ不足、UUID でない | X-Requested-With 付与・projectId は UUID |
| 500 `00000099` | body 不正・必須欠落 | パラメータ見直し |
| 200 + HTML | SPA フォールバック | 4.3 で検知 |

## 5. データ構造

### 5.1 loadProjectPages（シート一覧）

```json
[{ "projectId": "...", "id": "(pageId)", "title": "シート名",
   "pageType": "ISSUE | DASHBOARD", "sourceId": "(=wbsId)", "creator": {} }]
```

### 5.2 getPageDetail.optionalData（シートスキーマ）

- `code`: シートコード（URL の sheetCode と突合してシートを一意特定）
- `defaultLayout`: GANTT / GRID / KANBAN
- `linkedNodeFields[].field`: 列定義 `{id, name, valueType}` — CSV 全列モードのスキーマソース（ADR-8）
  - 標準 15 列: taskId, title, priority(SINGLE_SELECT), assignee(USER_SINGLE_SELECT), status(SINGLE_SELECT), progress(PERCENT), expectedProgress, plannedDuration(NUMBER), plannedStart(DATE), plannedEnd(DATE), plannedEffort(EFFORT), actualEffort, effortVariance, predecessor(MULTI_SELECT), description(TEXT)
- `statusSet.statuses[]`: `{id, name, extraData:{ja,en}}`（未開始 / 実行中 / 完了 / 保留 / 対応不要）。
  ステータス名 → id の解決に使用

### 5.3 getWbsNodes（タスクツリー）

```json
{ "pathToDisplayRoot": [{"id": "..."}],
  "displayRoot": {
    "id": "...",
    "data": {
      "taskId": "SAMPLE-1", "title": "...", "type": "PACKAGE | MILESTONE | TASK",
      "status": {"id": "NOT_STARTED", "name": "Not start", "extraData": {"ja": "未開始"}},
      "plannedDuration": 7200, "plannedEffort": 480,
      "actualStart": 1690675200000, "actualEnd": 1690761599999,
      "predecessor": [ { "...": "api-write.md セクション 5 参照" } ],
      "creator": {}, "updater": {}
    },
    "children": [ {"id": "...", "data": {}, "children": []} ]
  },
  "ranks": {} }
```

重要な仕様:

- 日付は **epoch ミリ秒**。**未設定の値はキー自体が無い**
- シートによっては `plannedStart` / `plannedEnd` / `progress` / `assignee` / `priority` が
  **全ノードに存在しない**（getPageDetail に列定義はあるが値未設定）。これらは欠落前提で処理する
- `plannedDuration` の単位は**分が基本**（1440 = 暦日 1 日）だが日単位らしき小値が混在するシートあり。
  `analyze_schedule.py` はシート全体の中央値から単位を自動判定する
- `plannedEffort` は EFFORT 型・分単位（480 = 8h = 1 人日と推定）

### 5.4 predecessor（先行タスク・読み取り形式）

```json
"predecessor": [{
  "entityId": "(このタスクの entityId)",
  "dependentEntityId": "(先行タスクの entityId = ノード id)",
  "dependentEntityNumber": 8,
  "type": "FS",
  "lag": null,
  "wbsId": "...", "createTime": "...", "entityDeleted": false,
  "dependenceKey": {"entityId": "...", "dependentEntityId": "..."}
}]
```

- `dependentEntityNumber` = 先行タスクの taskId 数値部（`SAMPLE-8` → `8`）
- `type` は FS（Finish-to-Start）のみ実証。`lag` は null（未設定）が既定

## 6. データ取得フロー（メインシナリオ）

```
入力: URL /wbs/project/{urlKey}/issue/{sheetCode}?lyt=1（または tenant + projectId(UUID) + sheetCode）
  │
  ├─[0] tenant を確定（URL から抽出 or 入力）→ BASE URL 構築
  ├─[1] urlkey.py で urlKey → projectId(UUID)（URL 入力時のみ）
  ├─[2] list_sheets.sh → シート一覧
  │       ・sheetCode があれば getPageDetail.optionalData.code と突合して一意特定
  │       ・特定できず ISSUE が複数なら Claude 層で AskUserQuestion
  ├─[3] (任意) sheet_detail.sh → 列定義・statusSet
  └─[4] get_tasks.sh（wbsId = sourceId）→ タスクツリー
          → tasks_to_csv.py / analyze_schedule.py で整形
```

シート選択ロジック（ISSUE フィルタ・sheetCode 突合・複数候補時の確認）は Claude エージェント層が担い、
スクリプトは JSON 取得のみを行う。
