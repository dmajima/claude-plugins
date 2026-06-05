# Case 06: エラー系（範囲外パスでの teardown 拒否、3 段ガード + fail-closed）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv を削除（誤って範囲外パス指定）" |
| 引数 | `teardown --work-dir /home/user/some-project` |
| フラグ | なし |
| 既存状態 | `/home/user/some-project/.venv` が存在 |

## 期待動作

### Phase 1: 安全装置 1（パス正規化、fail-closed）

`teardown_venv.sh` 内部で `[System.IO.Path]::GetFullPath` を呼び出してシンボリックリンク迂回を防ぐ。
解決に失敗する環境では **fail-closed**（exit 1）で削除を拒否する。下記コード例は旧 Bash 実装の参考であり、現行は PowerShell 版で同等の安全装置を実装している。

```bash
if command -v realpath >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(realpath -m "${VENV_DIR}")
elif command -v readlink >/dev/null 2>&1; then
  RESOLVED_VENV_DIR=$(readlink -f "${VENV_DIR}")
else
  exit 1   # fail-closed
fi
```

その後、Windows のバックスラッシュをスラッシュに正規化:

```bash
NORMALIZED_PATH="${RESOLVED_VENV_DIR//\\//}"
```

### Phase 2: 安全装置 2（`.claude/.local/` 配下確認）

```bash
case "${NORMALIZED_PATH}" in
  *"/.claude/.local/"*) : ;;   # OK
  *) exit 1 ;;                  # 範囲外
esac
```

`/home/user/some-project/.venv` は `.claude/.local/` 配下ではないため拒否。

### Phase 3: 安全装置 3（システムパス二重チェック）

正規化後パスがシステムルート風（`/` / `/root` / `/home` / `/etc` / `/usr` / `/var` / `/bin` / `/sbin` / `/opt` / `/Users` / Windows ドライブルート `C:/`）に該当するかを二重チェック。
合致する場合、`.claude/.local/` を含む場合のみ許容、それ以外は拒否。

### Phase 4: エラーメッセージ

```text
[teardown_venv] Error: venv path is not under .claude/.local/, refusing to delete.
  target (input): /home/user/some-project/.venv
  target (resolved): /home/user/some-project/.venv
  target (normalized): /home/user/some-project/.venv
```

### Phase 5: ユーザへの説明

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
| 標準出力 | エラーメッセージ（input / resolved / normalized 全てを表示）+ 許可される配置先の説明 |
| 終了状態 | 失敗（exit 1） |

## 分岐の根拠

teardown 対象パスが `.claude/.local/` 配下でない、または realpath/readlink 不在環境（fail-closed）。
3 段ガードのいずれかが作動した時点で削除を拒否する。

## 関連ケース

- `case-03_teardown.md`（正常な teardown）
