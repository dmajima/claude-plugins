# Case 03: タスク追加（承認 → addNode → 反映検証）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ProjectBoard の外部WBS シートの『テストフェーズ』配下に『回帰テスト実施』というタスクを追加して" |
| 引数 | 対象シート + 親パッケージ名 + 新規タスクタイトル |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に `hue-projectboard` エントリあり。シートに「テストフェーズ」PACKAGE が存在 |

## 期待動作

### Phase 1-2: 認証事前確認・セッション確立
- case-01 と同様（domains 照合 → login.sh）

### Phase 3: 操作種別判定
- 「タスクを追加」を書き込みと判定し Step 5（書き込み系）へ進む

### Phase 4: 現状取得・配置解決
- `get_tasks.sh` で最新のタスクツリーを取得
- 「テストフェーズ」に一致する PACKAGE ノードを特定し、その id を parentId とする
- 挿入位置（既定: 親の末尾 = 最後の子の id を preSiblingId）を決定する。親候補が複数なら AskUserQuestion

### Phase 5: 機密チェック・承認
- タイトル「回帰テスト実施」に機密パターンが無いことを確認
- 追加先（テナント / シート / 親パッケージ）・タイトル・種別（TASK）・挿入位置を提示し、
  `AskUserQuestion` で承認を得る（承認なしで POST しない）

### Phase 6: 実行・反映検証
- operationId(UUID)・connectionId(8 文字)・新規ノード id(UUID) を生成
- jq で addedNodeForest ボディを構築（タイトルは --rawfile 経由）し、
  `post_node_api.sh <WORK_DIR> addNode <body>` で POST（XSRF 自動付与）
- レスポンス確認後、`get_tasks.sh` で再取得し新タスクが親配下に存在することを jq で検証する
- 反映されない場合: api-write.md セクション 8 のフォールバック（ブラウザで 1 回操作 → HAR 採取 →
  仕様確定 → api-write.md 更新）をユーザーに案内する

### Phase 7: 後始末・報告
- cleanup_sensitive.sh を実行し、追加されたタスク（taskId・配置）を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（ProjectBoard 側にタスク 1 件追加。ローカル機密ファイルは削除済み） |
| 標準出力（要約） | 承認質問 → 追加完了報告（taskId / 親 / 位置）+ 反映検証の結果 |
| 終了状態 | 成功（続けて日付設定・担当者設定等が必要かを確認） |

## 分岐の根拠

操作種別 = 書き込み（タスク追加）である。書き込みは AskUserQuestion 承認を通過するまで POST が
発行されず、実行後の反映検証（再取得）が必須となる（addNode のボディ全体形が推定仕様のため）。

## 関連ケース

- `case-04_task_update.md`（同じ書き込みだが既存ノードのフィールド更新）
- `case-01_task_read.md`（承認ゲートを経由しない読み取りの対比）
