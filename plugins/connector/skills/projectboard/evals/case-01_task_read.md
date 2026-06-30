# Case 01: タスク一覧の CSV 化（読み取り）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "ProjectBoard のこのシートのタスクを CSV にして https://example-tenant.pm.apps.worksap.com/wbs/project/abcDEFghiJKLmnoPQRst/issue/xYzW?lyt=1" |
| 引数 | シート URL（tenant / urlKey / sheetCode を含む） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `hue-projectboard` エントリが存在し、`domains` に `example-tenant.pm.apps.worksap.com`（またはワイルドカード `pm.apps.worksap.com`）を含む |

## 期待動作

### Phase 1: 認証事前確認
- URL から tenant `example-tenant` を抽出し、credentials.json の `hue-projectboard.domains` と照合する
- username / value の非空を確認する（フル値は会話出力しない）

### Phase 2: 入力解決・セッション確立
- セッション作業領域を確保し、venv を構築する（setup_venv.sh）
- urlKey `abcDEFghiJKLmnoPQRst` を `urlkey.py` で UUID `0bc4978b-41e7-11f1-9633-85b8872b7139` に変換する
- `PB_TENANT` / `PB_EMAIL` / `PB_PASSWORD` 環境変数で `login.sh` を実行し、redirect が `/wbs/projects/quick` で成功判定

### Phase 3: 操作種別判定
- 「CSV にして」を読み取りと判定し Step 4（読み取り系）へ進む
- AskUserQuestion 承認ゲートは発火しない

### Phase 4: シート特定・取得・整形
- `list_sheets.sh` でシート一覧を取得し、sheetCode `xYzW` を `sheet_detail.sh` の optionalData.code と突合して一意特定
- `get_tasks.sh`（wbsId = sourceId）でタスクツリーを取得
- `tasks_to_csv.py`（standard モード 10 列）で CSV を生成

### Phase 5: 後始末・報告
- CSV をセッションフォルダ直下へ移動後、`cleanup_sensitive.sh` で cookies.txt・pb_*.json を削除
- タスク件数・列構成・CSV パスを報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | タスク CSV（セッションフォルダ直下）。cookies.txt・取得 JSON は削除済み |
| 標準出力（要約） | シート名・タスク件数・CSV パスの報告 |
| 終了状態 | 成功（続けて構造解析や書き込みが必要かを確認） |

## 分岐の根拠

操作種別 = 読み取り（CSV 化）である。Step 4 の読み取り経路に進み、Step 5 の書き込みゲート
（AskUserQuestion 承認）は経由しない。

## 関連ケース

- `case-02_sheet_structure.md`（同じ読み取りだが analyze_schedule.py による構造解析）
- `case-03_task_add.md`（同じシートへの書き込み。承認ゲートを通過する対比）
- `case-05_credentials_missing.md`（Phase 1 で停止する負例）
