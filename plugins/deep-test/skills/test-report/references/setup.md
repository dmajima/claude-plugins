# 環境構築（test-report）

報告書生成スクリプトの実行環境（venv）の構築・削除手順。実行手順本体は [procedures.md](procedures.md) を参照。
venv スクリプト・依存定義はプラグイン共通の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` に一元化されている（スキル個別には持たない）。

## 依存パッケージ

依存パッケージ（PyYAML / openpyxl）はプラグイン共通の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` で完全固定。これ以外は標準ライブラリのみを使用する。

## スクリプト一覧

| スクリプト | 役割 |
|-----------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` | `<work_dir>/.venv` の作成 + requirements.txt のインストール（`$SCRIPT_DIR/requirements.txt` を自動参照。`python` 不在時は `python3` へフォールバック） |
| `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh` | `<work_dir>/.venv` の削除 |

## venv 構築（Bash ツール経由）

venv はセッション作業領域の `workspace/.venv`（`.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv`）に作成。同一セッションで構築済み（PyYAML / openpyxl 導入済み）なら再構築せず再利用する。

```bash
SESSION_DIR=".claude/.local/work/{yyyyMMdd_nn_summary}"
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

- venv の Python は明示指定で使用: `$SESSION_DIR/workspace/.venv/Scripts/python.exe`（Windows）/ `$SESSION_DIR/workspace/.venv/bin/python`（Unix）

## venv 削除（タスク完了後）

後続タスクが Python を使わない場合のみ削除。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```
