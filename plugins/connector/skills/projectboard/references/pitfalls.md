# 既知の落とし穴（必読）

HUE ProjectBoard 連携で実機検証により判明した落とし穴。番号は安定参照用（変更しない）。

| # | 落とし穴 | 対策 |
|---|---|---|
| 1 | ログインパラメータは `username`（`email` ではない）。値はメールアドレス | `--data-urlencode 'username=<メール>'`（login.sh 実装済み） |
| 2 | URL の ID は urlKey（base62）、API は UUID を要求 | `resolve/urlkey.py` で変換 + round-trip 自己検証ガード（ADR-7） |
| 3 | `getWbsNodes` の wbsId は loadProjectPages の **sourceId**（pageId ではない） | list_sheets.sh の出力から sourceId を使用 |
| 4 | node 系 API は GET も POST も **同一 base `/wbs/wbs/node`**（読み取りと書き込みで同じ axios インスタンス） | [api-write.md](api-write.md) に SSOT 化。`/wbs/project/node` への POST は 500（過去版の誤りを訂正済み） |
| 5 | `X-Requested-With: XMLHttpRequest` が無いと 400 illegalArgs | 全 API に付与（スクリプト実装済み） |
| 6 | POST は CSRF 必須（403）。GET は不要 | post_node_api.sh が X-XSRF-TOKEN を自動付与・403 時再取得 |
| 7 | **書き込みには生きた WebSocket+STOMP 接続が必須**（connectionId = SockJS session_id をサーバが接続検証）。受信専用ではない | 書き込み前に `stomp_session.py` で WebSocket+STOMP CONNECT し、接続保持中に REST 書き込み（ADR-1 の方式に代わり本方式を採用） |
| 8 | パラメータ不足時に 200 + SPA の HTML が返る | 先頭バイトの `<!DOCTYPE` / `<html` 検知（with_session.sh / post_node_api.sh 実装済み） |
| 9 | SESSION タイムアウトで 401 | with_session.sh / post_node_api.sh が再ログイン + 1 回リトライ |
| 10 | 組織設定の SSO 切替でフォームログインが破綻しうる | login.sh の redirect 検知で明示エラー（exit 3） |
| 11 | API 仕様が不明・変わったとき | ブラウザ F12 の HAR 保存 → `jq '.log.entries[]'` 解析が最短（[api-write.md](api-write.md) セクション 8） |
| 12 | 日付・未設定値は**キー自体が無い**。シートによっては plannedStart/plannedEnd/progress/assignee が全ノードに存在しない | 欠落前提で処理する。CSV は空文字、CPM は duration フォールバック（analyze_schedule.py 実装済み） |
| 13 | `plannedDuration` の単位は分（1440=1日）が基本だが日単位らしき小値が混在するシートあり | analyze_schedule.py がシート全体の中央値で単位を自動判定（警告出力あり） |
| 14 | 書き込みボディは**実証済み仕様**（2026-06-12 実機検証で確定）。updateNodes は `newFieldValueMap`、ボディに projectId/wbsId/activityType 必須 | [api-write.md](api-write.md) 参照。`fieldValueMap` や projectId 欠落は 500 |
| 15 | predecessor の更新は配列全体の置換。要素は `{type:"FS", entityId(自分), dependentEntityId(先行), dependentEntityNumber(先行taskId数値)}` | 既存依存を読み取り値とマージしてから送る（[api-write.md](api-write.md) セクション 3.2） |
| 16 | predecessor 要素に `dependentEntityNumber` が無い場合、CSV では当該依存が空文字として無言で欠落する | 依存関係を正確に扱う用途では CSV でなく analyze_schedule.py の `--out-json`（edges に解決済み依存を保持）を使う |
| 17 | Git Bash + Windows curl.exe では `name@/tmp/...`・`--data-binary @/tmp/...` の **@file 埋め込み POSIX パス**が解釈不能（独立引数 `-o` 等は MSYS が自動変換するが @ 埋め込みは対象外） | login.sh / post_node_api.sh の `to_curl_path()`（cygpath -w 変換）を経由する。新規スクリプトで curl に @file を渡す場合も同様に変換する |
| 18 | type 変更（TASK⇄MILESTONE）に `type`/`milestone` フィールドは存在しない | `newFieldValueMap:{plannedDuration:0}` + activityType=`CONVERT_TYPE`（MILESTONE 化）。TASK 化は 0 以外 |
| 19 | ノード追加の `preSiblingId` を先頭で `"0"` にすると `01010401 illegalArgs` | 先頭は **`null`**、それ以外は直前兄弟の id（[api-write.md](api-write.md) セクション 4） |
| 20 | 複数の新規兄弟を 1 リクエストで同時追加すると illegalArgs（preSiblingId が同一リクエストの未確定 id を参照） | **1 ノードずつ追加**し、前ノードの実 id を次の preSiblingId にする |
| 21 | operationId は `connectionId + 単調増加カウンタ`。UUID 単独だと 500 | post_node_api.sh が `PB_CONNECTION_ID` から自動生成 |
