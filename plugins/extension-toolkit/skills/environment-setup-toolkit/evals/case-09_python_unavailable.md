# Case 09: setup 失敗系（Python 未インストール環境）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv 構築" |
| 引数 | `setup --work-dir .claude/.local/work/test/workspace --requirements scripts/deps/requirements.txt` |
| フラグ | なし |
| 既存状態 | 利用者環境に `python3` も `python` もインストールされていない |

## 期待動作

### Phase 1: Python コマンド検出

`setup_venv.sh` 内で以下の順序で検索:

```bash
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
else
  echo "[setup_venv] Error: python3/python not found in PATH." >&2
  exit 1
fi
```

両方とも見つからない場合 → **fail-closed**（exit 1）。

### Phase 2: エラーメッセージ + ユーザへの案内

```text
[setup_venv] Error: python3/python not found in PATH.

Python が利用者環境にインストールされていません。以下のいずれかで対応してください:
1. Python 3.10 以上をインストール（https://www.python.org/downloads/ 等）
2. すでにインストール済みなら PATH を確認: which python3 / where python3
3. 仮想環境管理ツール（pyenv 等）でバージョン切替
```

### Phase 3: 引き渡し

- venv は作成されない（Phase 1 で exit 1）
- ユーザに再実行の前提条件を提示
- 進捗管理ファイル（progress.md）に「環境構築失敗：Python 未存在」を記録

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 作成 venv | なし |
| 標準エラー出力 | `[setup_venv] Error: python3/python not found in PATH.` + 解決案内 |
| 終了状態 | 失敗（exit 1） |

## 分岐の根拠

利用者環境に Python 系コマンドが存在しない → ADR-022 自己完結性原則に従い、外部ツール前提が満たされない場合は明示エラーで停止。利用者に必要な前提を提示する。

## 関連ケース

- `case-01_setup_new_venv.md`（正常系: Python あり）
- `case-08_non_interactive.md`（非対話モード: 必須フラグ揃っていればエラー終了の挙動は同じ）
- `case-06_safety_check.md`（teardown の安全装置）
