# Case 02: シート全体の構造解析・クリティカルパス（読み取り）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "/connector:projectboard-sheet 外部WBS シートのクリティカルパスを分析して tenant=example-tenant projectId=0bc4978b-41e7-11f1-9633-85b8872b7139" |
| 引数 | tenant + projectId(UUID) + シート名（入力系統 B） |
| フラグ | なし（対話モード） |
| 既存状態 | credentials.json に `hue-projectboard` エントリあり。対象シートに predecessor（先行タスク）定義が一部存在する |

## 期待動作

### Phase 1: 認証事前確認
- tenant `example-tenant` のホストを `hue-projectboard.domains` と照合する

### Phase 2: 入力解決・セッション確立
- UUID 直接指定のため urlkey.py 変換は不要（UUID 形式バリデーションのみ）
- login.sh でセッション確立

### Phase 3: 操作種別判定
- 「構造解析・クリティカルパス」を読み取り（解析）と判定し Step 4 へ進む

### Phase 4: シート特定・解析
- `list_sheets.sh` の結果から ISSUE シートをシート名「外部WBS」と一致で特定
- **サブ分岐（シートが一意に特定できない場合）**: 名前一致なし / 複数の ISSUE シートが該当する場合は、
  AskUserQuestion で候補（title・pageType）を提示して選択してもらう。推測でシートを選ばない
- `get_tasks.sh` でタスクツリーを取得
- `analyze_schedule.py --out-json` で Markdown レポート + 構造化 JSON を生成:
  - サマリ（ノード総数・type/status 内訳・予定/実績期間・依存件数・CPM 総工期）
  - WBS ツリー（クリティカルノードに ★CP マーク）
  - 依存関係一覧（先行 → 後続・type・lag）
  - CPM 分析（ES/EF/LS/LF/float 表・float=0 経路。依存が部分的な場合はその旨を明示）
  - 警告（plannedDuration 単位の自動判定・循環依存・未解決参照）

### Phase 5: 後始末・報告
- レポートをセッションフォルダ直下へ移動後、cleanup_sensitive.sh を実行
- クリティカルパス・総工期・依存の充足状況を要約して報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 解析レポート（.md）と構造化データ（.json）。cookies.txt・取得 JSON は削除済み |
| 標準出力（要約） | クリティカルパス / 総工期 / 警告の要約 + レポートパス |
| 終了状態 | 成功 |

## 分岐の根拠

操作種別 = 読み取り（シート全体の構造解析）である。analyze_schedule.py を使用する解析経路に進み、
書き込みゲートは経由しない。依存定義が部分的なシートでは「float=0 の依存チェーンが形成されない」旨を
レポートが明示する（CPM 上は最長 duration の独立タスクが工期を支配する）。

## 関連ケース

- `case-01_task_read.md`（同じ読み取りだが CSV 整形のみ）
- `case-06_session_expired.md`（取得中に 401 が発生した場合の自動回復）
