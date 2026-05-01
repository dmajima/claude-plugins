# Case 01: setup（新規 venv 構築）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Python venv を作って、requirements.txt をインストール" |
| 引数 | `setup --work-dir .claude/.local/work/20260430_01_test/workspace --requirements .claude/.local/work/20260430_01_test/requirements.txt` |
| フラグ | なし |
| 既存状態 | venv 未作成、requirements.txt 存在 |

## 期待動作

### Phase 1: 環境チェック

`python --version` 成功確認、作業ディレクトリ書き込み可。

### Phase 2: venv 作成

`<work_dir>/.venv` 作成、pip 最新化。

### Phase 3: 依存インストール

`requirements.txt` の内容を venv にインストール。

### Phase 4: 検証 + 引き渡し

- Python 実行可能
- インストール済みパッケージ一覧
- venv パス提示

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成 | `.claude/.local/work/20260430_01_test/workspace/.venv/` |
| 標準出力 | venv パス、Python バージョン、インストール件数、利用例 |
| 終了状態 | 成功 |

## 分岐の根拠

動作 = setup + venv 不在 + requirements 指定あり。

## 関連ケース

- `case-02_setup_reuse.md`（venv 既存時の再利用）
- `case-04_refresh.md`（既存を作り直す）
