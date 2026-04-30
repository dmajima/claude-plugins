# Case 07: setup（requirements.txt 不在 / 指定なし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Python venv だけ作って（依存なし）" |
| 引数 | `setup --work-dir .claude/.local/work/20260430_01_test/workspace`（`--requirements` 省略） |
| フラグ | なし |
| 既存状態 | venv 未作成 |

## 期待動作

### Phase 1: 環境チェック

通常チェック。

### Phase 2: venv 作成

`<work_dir>/.venv` 作成、pip 最新化。

### Phase 3: 依存インストールスキップ

`--requirements` 省略のため、依存インストールをスキップ。`setup_venv.sh` 内部の処理で `REQUIREMENTS_PATH` が空のためインストール処理を実行しない。

### Phase 4: 検証 + 引き渡し

- venv 存在
- Python 実行可能
- `pip list` の結果は基本パッケージ（pip / setuptools / wheel）のみ

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成 | `<work_dir>/.venv/`（基本パッケージのみインストール） |
| 標準出力 | venv パス、Python バージョン、「依存パッケージなしで構築」メッセージ |
| 終了状態 | 成功 |

## 分岐の根拠

`--requirements` 省略 + venv 不在。最小構成での venv 作成パスをカバーする。

## 関連ケース

- `case-01_setup_new_venv.md`（requirements.txt あり）
- `case-02_setup_reuse.md`（既存 venv 再利用）
