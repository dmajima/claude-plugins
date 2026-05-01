# Case 02: setup（既存 venv 再利用）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Python venv セットアップ" |
| 引数 | `setup --work-dir .claude/.local/work/20260430_01_test/workspace --requirements .../requirements.txt` |
| フラグ | なし |
| 既存状態 | venv 既存、requirements.txt 存在 |

## 期待動作

### Phase 1: 環境チェック

通常チェック。既存 venv 検出。

### Phase 2: 再利用判断

「既存 venv が見つかりました。再利用しますか？」と AskUserQuestion で確認:

- 1. 再利用（推奨） — 既存 venv を残し、依存だけ更新
- 2. 再構築（refresh） — 削除してから新規構築
- 3. キャンセル

### Phase 3: 再利用選択時

既存 venv に対し pip 最新化 + requirements インストールを実行。

### Phase 4: 検証 + 引き渡し

通常検証。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成 | 既存 venv の内容更新（差分のみ） |
| 標準出力 | 既存 venv 検出、再利用の確認結果、更新パッケージ一覧 |
| 終了状態 | 成功（or キャンセル） |

## 分岐の根拠

動作 = setup + venv 既存。

## 関連ケース

- `case-01_setup_new_venv.md`（新規構築）
- `case-04_refresh.md`（明示的な再構築）
