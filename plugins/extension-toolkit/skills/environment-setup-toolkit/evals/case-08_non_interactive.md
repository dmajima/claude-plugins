# Case 08: 非対話モード（全パラメータ引数指定）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "environment-setup-toolkit setup を非対話で実行" |
| 引数 | `setup --work-dir .claude/.local/work/20260430_01_test/workspace --requirements .claude/.local/work/20260430_01_test/requirements.txt --min-python-version 3.10` |
| フラグ | `--non-interactive` |
| 既存状態 | venv 未作成、requirements.txt 存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` フラグありのため、対話せず引数値で確定する。

### Phase 2: 環境チェック（非対話）

- Python 実行可能性確認
- バージョン要件 `--min-python-version 3.10` を検証
- 作業ディレクトリ書き込み可確認
- 既存 venv 検出（不在）

ユーザ確認は行わず、要件を満たさない場合は **エラー終了**（中断）。

### Phase 3: venv 作成 + 依存インストール

case-01 と同じ手順。エラー時のみメッセージ出力。

### Phase 4: 完了報告のみ

確認・選択は行わず、結果サマリのみ標準出力する。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成 | `<work_dir>/.venv/`、依存パッケージインストール済 |
| 標準出力 | 完了報告（venv パス、Python バージョン、インストール件数）。質問なし |
| 終了状態 | 成功（エラー時は exit 1） |

## 分岐の根拠

`--non-interactive` フラグ + 全必須パラメータ引数指定。他スキルからの自動呼び出し（バッチ処理）の典型ケース。

## 関連ケース

- `case-01_setup_new_venv.md`（対話モード、新規構築）
- `case-02_setup_reuse.md`（対話モード、既存再利用）
- `case-07_setup_no_requirements.md`（依存なし、対話モード）
