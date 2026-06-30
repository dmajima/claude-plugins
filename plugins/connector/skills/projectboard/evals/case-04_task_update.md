# Case 04: ステータス更新（ID 解決 → 承認 → updateNodeContent）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/connector:projectboard-update SAMPLE-67 のステータスを実行中に、進捗を 50% にして（外部WBS シート）" |
| 引数 | タスク ID + 変更フィールド 2 件（ステータス・進捗） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に `hue-projectboard` エントリあり。SAMPLE-67 が存在し現在ステータス「未開始」 |

## 期待動作

### Phase 1-2: 認証事前確認・セッション確立
- case-01 と同様

### Phase 3: 操作種別判定
- 「ステータスを〜にして」を書き込み（タスク更新）と判定し Step 5 へ進む

### Phase 4: 現状取得・ID 解決
- `get_tasks.sh` で最新ツリーを取得し、taskId `SAMPLE-67` のノード id と現在値（ステータス「未開始」）を特定
- `sheet_detail.sh` の statusSet.statuses[] から「実行中」を id（例 `IN_PROGRESS`）に解決する
  （extraData.ja / name → id。曖昧・不一致なら候補を提示）

### Phase 5: 承認
- 対象タスク（SAMPLE-67 / タイトル）・変更内容を **変更前 → 変更後** で提示する:
  - ステータス: 未開始 → 実行中
  - 進捗: （未設定） → 50%
- `AskUserQuestion` で承認を得る（承認なしで POST しない）

### Phase 6: 実行・反映検証
- jq で updateNodes + fieldValueMap（status / progress のみ。他フィールドを含めない）ボディを構築し、
  `post_node_api.sh <WORK_DIR> updateNodeContent <body>` で POST
- 再取得して SAMPLE-67 の status / progress が期待値に変わったことを検証する
- 反映されない場合は api-write.md セクション 8 のフォールバックを案内する

### Phase 7: 後始末・報告
- cleanup_sensitive.sh を実行し、変更内容（前 → 後）を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（ProjectBoard 側のタスク 1 件が更新。ローカル機密ファイルは削除済み） |
| 標準出力（要約） | 変更前後の提示 → 承認質問 → 更新完了報告 + 反映検証の結果 |
| 終了状態 | 成功 |

## 分岐の根拠

操作種別 = 書き込み（フィールド更新）である。updateNodeContent はフィールド単位の部分更新であり、
指定された status / progress のみを fieldValueMap に含める（依頼外フィールドを巻き込まない）。
ステータスは表示名でなく statusSet の id に解決してから送る。

## 関連ケース

- `case-03_task_add.md`（同じ書き込みだが新規ノード作成）
- `case-02_sheet_structure.md`（更新後の影響をクリティカルパスで確認する後続操作）
