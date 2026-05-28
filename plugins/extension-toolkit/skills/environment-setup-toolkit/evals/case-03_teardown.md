# Case 03: teardown（venv 削除）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv を削除して" |
| 引数 | `teardown --work-dir .claude/.local/work/20260430_01_test/workspace` |
| フラグ | なし |
| 既存状態 | venv 既存 |

## 期待動作

### Phase 1: 削除対象確認

venv パスが `.claude/.local/` 配下であることを安全装置で検証。

### Phase 2: ユーザ確認（重要操作）

AskUserQuestion で削除確認:

- 1. 削除する
- 2. キャンセル

### Phase 3: 削除実行

`teardown_venv.sh` を呼び出し、venv ディレクトリを削除（Bash 標準・PowerShell フォールバック）。

### Phase 4: 検証 + 引き渡し

削除後の不在確認。進捗管理に反映。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 削除 | `<work_dir>/.venv/` |
| 標準出力 | 削除確認、サイズ削減の通知 |
| 終了状態 | 成功（or キャンセル） |

## 分岐の根拠

動作 = teardown。

## 関連ケース

- `case-04_refresh.md`（teardown + setup の連続）
- `case-06_safety_check.md`（範囲外パスでの拒否）
