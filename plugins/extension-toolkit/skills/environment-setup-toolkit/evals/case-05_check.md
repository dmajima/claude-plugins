# Case 05: check（状態確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv の状態を確認して" |
| 引数 | `check --work-dir .../workspace [--requirements .../requirements.txt]` |
| フラグ | なし |
| 既存状態 | venv 既存 or 不在 |

## 期待動作

### Phase 1: 存在確認

venv 有無を確認。

### Phase 2: 状態取得（venv 既存時）

| 項目 | 取得方法 |
|-----|---------|
| Python バージョン | `python --version` |
| インストール済パッケージ | `pip list` |
| requirements.txt との差分 | `pip freeze` と requirements.txt を比較 |

### Phase 3: 結果サマリ提示

```text
venv 状態:
- パス: <work_dir>/.venv
- Python: 3.11.5
- パッケージ数: 12

requirements.txt との差分:
- 一致: 10 件
- バージョン違い: 1 件（pkg_a 1.2.0 -> 1.2.5）
- 不足: 1 件（pkg_b）
```

### Phase 4: 引き渡し

| 状況 | 提案 |
|-----|------|
| 一致 | 「環境は最新です」 |
| 差分あり | refresh の提案 |
| venv 不在 | setup の提案 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 状態サマリ + 必要に応じた次アクション提案 |
| 終了状態 | 成功（読み取り専用） |

## 分岐の根拠

動作 = check（読み取り専用）。

## 関連ケース

- `case-01_setup_new_venv.md`（venv 不在時の構築）
- `case-04_refresh.md`（差分時の再構築）
