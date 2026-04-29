# Case 06: エラー系（範囲外パスでの teardown 拒否）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv を削除（誤って範囲外パス指定）" |
| 引数 | `teardown --work-dir /home/user/some-project` |
| フラグ | なし |
| 既存状態 | `/home/user/some-project/.venv` が存在 |

## 期待動作

### Phase 1: パス検証

`teardown_venv.sh` 内部の安全装置:

```bash
case "${VENV_DIR}" in
  *"/.claude/.local/"*) : ;;  # OK
  *) exit 1 ;;                # 範囲外
esac
```

`/home/user/some-project/.venv` は `.claude/.local/` 配下ではないため拒否。

### Phase 2: エラーメッセージ

```text
[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete.
  target: /home/user/some-project/.venv
```

### Phase 3: ユーザへの説明

```text
範囲外のパスは安全のため削除しません。

許可される配置先:
- .claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv
- .claude/.local/skills/{name}/.venv
- .claude/.local/plugins/{name}/.venv

該当パスでない場合は手動で削除してください。
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 削除 | なし（拒否） |
| 標準出力 | エラーメッセージ + 許可される配置先の説明 |
| 終了状態 | 失敗（exit 1） |

## 分岐の根拠

teardown 対象パスが `.claude/.local/` 配下でない（安全装置作動）。

## 関連ケース

- `case-03_teardown.md`（正常な teardown）
