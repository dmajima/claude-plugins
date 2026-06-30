# Case 04: ステータス変更（ID 解決 → 変更前後の提示 → 承認 → PATCH）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PROJ-123 のステータスを処理中に変更して" |
| 引数 | 課題キー `PROJ-123` + ステータス名 `処理中`（スペースは `example.backlog.jp`） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に対象スペースのエントリあり / PROJ-123 の現在のステータスは `未対応` / プロジェクト PROJ のステータス一覧に `処理中` が一意に存在する |

## 期待動作

### Phase 1: 認証事前確認

- `example.backlog.jp` を credentials.json の `domains` と照合し、API キーの存在を確認する

### Phase 2: 操作種別判定

- 「課題メタ情報更新（ステータス変更）」を **書き込み** と判定し、SKILL.md Step 4 へ進む

### Phase 3: ステータス名 → statusId 解決

- `GET /api/v2/projects/PROJ/statuses` でステータス一覧（`id` / `name`）を取得する（api-read.md 操作 5）
- `処理中` に一致するエントリが 1 件のため、その `id`（例: 2）を `statusId` として確定する
- 一致が複数 / 0 件の場合は候補一覧を提示して確定する（このケースでは発生しない）

### Phase 4: 変更前の値の取得と承認

- `GET /api/v2/issues/PROJ-123` で現在のステータス `未対応` を取得する
- 「PROJ-123 のステータス: 未対応 → 処理中」の変更前後を提示し、`AskUserQuestion` で承認を得る
- 本文（content / comment / description）の変更を伴わない ID 系のみの更新のため、render-check は実行しない（承認は省略しない）

### Phase 5: 更新の実行

- `PATCH /api/v2/issues/PROJ-123` を `--data-urlencode "statusId=2"` のみで呼び出す（指定外フィールドをパラメータに含めない）
- apiKey は `--config` ファイル経由・`--max-time 30`・HTTP コード分岐は safe-api-access.md セクション 5 に従う

### Phase 6: 結果検証・報告

- レスポンスの `status.name` が `処理中` と一致することを確認する
- 変更内容（未対応 → 処理中）と課題 URL `https://example.backlog.jp/view/PROJ-123` を報告する
- レスポンスが期待と異なる場合は直ちにユーザーへ報告する（黙って追加修正しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（Backlog 側の課題ステータスが更新される。ローカル一時ファイルは削除済み） |
| 標準出力（要約） | statusId 解決結果 → 変更前後の提示と承認質問 → 更新完了報告（更新後ステータス + 課題 URL） |
| 終了状態 | 成功（続けてコメント追記等が必要かを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは 操作種別 = 書き込みのうちメタ情報のみの更新（本文なし・ID 解決必要）である。`statusId` は名前のままでは API に渡せないため一覧 API による ID 解決を経由し、render-check は api-write.md セクション 3 の表に従い不要（ID 系のみ）だが、変更前後の提示と AskUserQuestion 承認は必須となる。

## 関連ケース

- `case-03_comment_post.md`（本文を伴う書き込み。render-check ゲートが追加で必須になる）
- `case-02_issue_search.md`（同じ「名前 → ID 解決」のための一覧 API を読み取り用途で使う）
- `case-01_issue_get.md`（変更前の値の取得に使う課題取得 API の読み取り単体ケース）
