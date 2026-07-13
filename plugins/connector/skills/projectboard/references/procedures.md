# 実行手順（projectboard スキル）

環境構築は [setup.md](setup.md) を先に参照すること（venv 構築・依存なしの明記・後始末）。
API 仕様の詳細は [api-spec.md](api-spec.md)（読み取り）/ [api-write.md](api-write.md)（書き込み）を参照。

## 0. スクリプト共通規約

すべての `references/scripts/**/*.sh` / `*.py` が従う規約:

| 規約 | 内容 |
|---|---|
| WORK_DIR | 第 1 引数でセッション作業領域（`.claude/.local/work/{session}/workspace`）を受け取る。出力は全て `$WORK_DIR` 配下 |
| Cookie | `$WORK_DIR/cookies.txt` をスクリプト間で共有。相対パス `cookies.txt` 禁止 |
| 認証値 | `PB_TENANT` / `PB_EMAIL` / `PB_PASSWORD` 環境変数で受け渡す。スクリプト内で credentials.json を直接読まない（値の取得は Claude エージェント層が [credentials-precheck.md](../../../references/credentials-precheck.md) セクション 1 の解決順序＝credentials-manager（導入時）→ credentials.json 直接照合 → 対話取得フォールバックで行う）。パスワードはコマンドライン引数に乗せない |
| 機密マスク | ログ / 標準出力に Cookie 値・パスワード・トークンを出さない |
| Python | venv の python を明示指定。先頭で `sys.stdout.reconfigure(encoding='utf-8')`。`open()` は `encoding='utf-8'` 明示 |

## 1. 共通: 入力解決と認証

### 1.1 入力の 2 系統（ADR-6: tenant 第一級）

| 系統 | 構成 | 例 |
|---|---|---|
| A. URL | tenant / urlKey / sheetCode を URL から抽出 | `https://{tenant}.pm.apps.worksap.com/wbs/project/{urlKey}/issue/{sheetCode}?lyt=1` |
| B. 明示指定 | tenant + projectId(UUID) + sheetCode（任意） | tenant=`example-tenant`, projectId=`0bc4978b-...` |

URL 入力時の urlKey → UUID 変換:

```bash
PY="$WORK_DIR/.venv/Scripts/python.exe"   # Unix は .venv/bin/python
UUID=$("$PY" "${CLAUDE_SKILL_DIR}/references/scripts/resolve/urlkey.py" "$URLKEY")
```

### 1.2 認証情報の取得とログイン

1. Claude エージェント層が [credentials-precheck.md](../../../references/credentials-precheck.md)
   セクション 1 の解決順序で認証値（username=メール / value=パスワード）を取得する
   （credentials-manager（導入時）→ credentials.json の `hue-projectboard` エントリ → 対話取得フォールバック）
2. tenant のホスト `{tenant}.pm.apps.worksap.com` の許可を確認する — credentials.json 利用時は
   同エントリの `domains` 合致（ワイルドカード `pm.apps.worksap.com` 含む）、対話取得時は
   ユーザー本人が明示指定したテナントであること（合致・確認できないテナントへはアクセスしない）
3. ログイン実行:

```bash
PB_TENANT="$TENANT" PB_EMAIL="$EMAIL" PB_PASSWORD="$PASSWORD" \
  bash "${CLAUDE_SKILL_DIR}/references/scripts/auth/login.sh" "$WORK_DIR"
```

以降の fetch / write スクリプトにも同じ環境変数を渡す（401 時の自動再ログインに使用）。

## 2. 読み取り: シート特定とタスク取得

```bash
ENV=(env PB_TENANT="$TENANT" PB_EMAIL="$EMAIL" PB_PASSWORD="$PASSWORD")

# [1] シート一覧 → $WORK_DIR/pb_sheets.json
"${ENV[@]}" bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/list_sheets.sh" "$WORK_DIR" "$UUID"

# [2] シート特定（Claude エージェント層が実施）
#   - pageType=ISSUE で絞り込み
#   - sheetCode があれば sheet_detail.sh の optionalData.code と突合して一意特定
#   - 一意に特定できなければ AskUserQuestion で候補（title）を提示して選択してもらう
jq -r '.[] | select(.pageType == "ISSUE") | "\(.title)\t\(.id)\t\(.sourceId)"' "$WORK_DIR/pb_sheets.json"

# [3] (任意) 列定義・statusSet → $WORK_DIR/pb_pagedetail.json
"${ENV[@]}" bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/sheet_detail.sh" "$WORK_DIR" "$UUID" "$PAGE_ID"

# [4] タスクツリー → $WORK_DIR/pb_wbsnodes.json（wbsId は sourceId — 落とし穴 #3）
"${ENV[@]}" bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/get_tasks.sh" "$WORK_DIR" "$SOURCE_ID"
```

### 2.1 特定タスクの読み取り

タスクツリー JSON から jq で抽出する（taskId / title で検索）:

```bash
jq -r --arg key "SAMPLE-67" \
  '.displayRoot | recurse(.children[]?) | .data | select(.taskId == $key)' \
  "$WORK_DIR/pb_wbsnodes.json"
```

ノード id が必要な場合（書き込みの対象指定）は data と同階層の id を拾う:

```bash
jq -r --arg key "SAMPLE-67" \
  '.displayRoot | recurse(.children[]?) | select(.data.taskId == $key) | {id, data}' \
  "$WORK_DIR/pb_wbsnodes.json"
```

### 2.2 タスク一覧の CSV 化

```bash
# 標準 10 列
"$PY" "${CLAUDE_SKILL_DIR}/references/scripts/format/tasks_to_csv.py" \
  "$WORK_DIR/pb_wbsnodes.json" "$WORK_DIR/pb_tasks.csv"

# 全列（シートの列定義から動的生成 — ADR-8。pb_pagedetail.json が必要）
"$PY" "${CLAUDE_SKILL_DIR}/references/scripts/format/tasks_to_csv.py" \
  "$WORK_DIR/pb_wbsnodes.json" "$WORK_DIR/pb_tasks.csv" \
  --mode all --page-detail "$WORK_DIR/pb_pagedetail.json"
```

## 3. シート全体の構造解析（クリティカルパス含む）

```bash
"$PY" "${CLAUDE_SKILL_DIR}/references/scripts/format/analyze_schedule.py" \
  "$WORK_DIR/pb_wbsnodes.json" \
  --out-json "$WORK_DIR/pb_analysis.json" > "$WORK_DIR/pb_analysis.md"
```

出力内容: サマリ（type/status 内訳・期間・依存件数・総工期）/ WBS ツリー / 依存関係一覧 /
クリティカルパス分析（CPM: ES・EF・LS・LF・total float・float=0 経路）/ 警告（循環依存・
未解決参照・duration 推定根拠）。

- ツリーが大きい場合は `--max-depth N` で表示階層を制限できる（全データは --out-json 側に保持）
- 依存が未定義のシートでは CPM 経路は出ず、duration 上位タスクが参考表示される
- レポート（pb_analysis.md）を成果物として残す場合はセッションフォルダ直下へ移動してから後始末する

## 4. 書き込み: タスクの追加・更新

> 書き込みは必ず SKILL.md の書き込みゲート（変更内容の提示 + AskUserQuestion 承認）を通過してから実行する。
> ボディ仕様の詳細は [api-write.md](api-write.md) を参照（2026-06-12 実機検証で確定済み）。

### 4.1 共通: WebSocket 接続経由で書き込む

すべての書き込みは `stomp_session.py` で WebSocket+STOMP 接続を張り、その接続を保持したまま
`post_node_api.sh` を実行する（connectionId が生きた接続でないと 500 — [api-write.md](api-write.md) セクション 1.2）。
ボディの `connectionId` / `operationId` は `"__INJECT__"` プレースホルダにし、post_node_api.sh が
`PB_CONNECTION_ID` から注入・生成する（operationId = connectionId + epochms）。

```bash
ENV=(env PB_TENANT="$TENANT" PB_EMAIL="$EMAIL" PB_PASSWORD="$PASSWORD")
write_node() {  # write_node <body.json>
  "${ENV[@]}" "$PY" "${CLAUDE_SKILL_DIR}/references/scripts/write/stomp_session.py" \
    "$WORK_DIR" "$TENANT" "$UUID" "$SOURCE_ID" \
    -- bash "${CLAUDE_SKILL_DIR}/references/scripts/write/post_node_api.sh" "$WORK_DIR" updateNodeContent "$1"
}
# 対象シートの最新状態を取得（対象ノード id・親 id・既存値の確認）
"${ENV[@]}" bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/get_tasks.sh" "$WORK_DIR" "$SOURCE_ID"
```

### 4.2 タスク追加（updateNodeContent の addNodes 経由）

```bash
NODE_ID=$("$PY" -c "import sys,uuid; sys.stdout.reconfigure(encoding='utf-8'); print(uuid.uuid4())")
# preSiblingId: 先頭は null、それ以外は直前兄弟の id（"0" は illegalArgs）
jq -n --arg wbsId "$SOURCE_ID" --arg pid "$UUID" --arg nodeId "$NODE_ID" \
      --arg parentId "$PARENT_ID" --arg pre "$PRE_SIBLING_ID" --arg title "$NEW_TITLE" \
  '{connectionId:"__INJECT__", operationId:"__INJECT__", projectId:$pid, wbsId:$wbsId,
    activityType:"CREATE", updateNodes:[],
    addNodes:[{id:$nodeId, data:{id:$nodeId, title:$title, type:"TASK", preference:{expanded:false}},
               parentId:$parentId, preSiblingId:($pre|if .=="" then null else . end),
               preSiblingIndex:0, addNodesBelowBlankLine:false, fields:["title"]}]}' \
  > "$WORK_DIR/pb_body.json"
chmod 600 "$WORK_DIR/pb_body.json"
write_node "$WORK_DIR/pb_body.json"
```

- **複数ノードの追加は 1 件ずつ**（前ノードの id を次の preSiblingId にする。同時追加は illegalArgs）
- 新規パッケージ + 子は、先にパッケージを追加してその id を親に、子を 1 件ずつ追加する

### 4.3 タスク更新（updateNodeContent）

```bash
# 例: ステータスと進捗の更新（status は statusSet.statuses[].id に解決してから渡す）
jq -n --arg wbsId "$SOURCE_ID" --arg pid "$UUID" --arg nodeId "$TARGET_NODE_ID" \
      --arg status "IN_PROGRESS" --argjson progress 50 \
  '{connectionId:"__INJECT__", operationId:"__INJECT__", projectId:$pid, wbsId:$wbsId,
    activityType:"UPDATE_PROPERTY",
    updateNodes:[{id:$nodeId, newFieldValueMap:{status:$status, progress:$progress}}], addNodes:[]}' \
  > "$WORK_DIR/pb_body.json"
write_node "$WORK_DIR/pb_body.json"
```

- updateNodes のキーは **`newFieldValueMap`**（`fieldValueMap` ではない）
- ステータス名 → id の解決は pb_pagedetail.json の `statusSet.statuses[]`（`extraData.ja` / `name` → `id`）
- type 変更（TASK⇄MILESTONE）は `newFieldValueMap:{plannedDuration:0}` + activityType=`CONVERT_TYPE`
- 先行タスク（predecessor）は `{type:"FS", entityId(自分), dependentEntityId(先行), dependentEntityNumber(先行taskId数値)}` の配列。配列全体置換のため既存値とマージ（[api-write.md](api-write.md) セクション 3.2）

### 4.4 結果検証（MANDATORY — api-write.md セクション 7）

```bash
# レスポンス確認
jq . "$WORK_DIR/pb_write_response.json"

# 再取得して反映確認
"${ENV[@]}" bash "${CLAUDE_SKILL_DIR}/references/scripts/fetch/get_tasks.sh" "$WORK_DIR" "$SOURCE_ID"
jq -r --arg key "$TASK_KEY" \
  '.displayRoot | recurse(.children[]?) | .data | select(.taskId == $key)' \
  "$WORK_DIR/pb_wbsnodes.json"
```

反映されていない場合は [api-write.md](api-write.md) セクション 8 のエラー早見表で原因を切り分ける
（エンドポイント `/wbs/wbs/node`・WebSocket 接続・preSiblingId=null・operationId 形式）。

## 5. 後始末（必須）

```bash
bash "${CLAUDE_SKILL_DIR}/references/scripts/cleanup/cleanup_sensitive.sh" "$WORK_DIR"
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" "$WORK_DIR"   # 後続タスクで使わない場合
```

成果物（CSV / 解析レポート）を残す場合は cleanup 前にセッションフォルダ直下へ移動する。
