# 環境構築（test-report）

報告書生成スクリプトの実行環境（venv）の構築・削除手順。実行手順本体は [procedures.md](procedures.md) を参照。
venv スクリプト・依存定義はプラグイン共通の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` に一元化されている（スキル個別には持たない）。

## 依存パッケージ

プラグイン共通の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` で完全固定する。

| パッケージ | 用途 |
|-----------|------|
| PyYAML | 実績 YAML（test-results.yaml / test-cases.yaml）の読み込み |
| openpyxl | Excel 報告書の全コード生成（テンプレートファイル不使用） |

これ以外は標準ライブラリのみを使用する。

## スクリプト一覧

| スクリプト | 役割 |
|-----------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` | `<work_dir>/.venv` の作成 + requirements.txt のインストール（`$SCRIPT_DIR/requirements.txt` を自動参照。`python` 不在時は `python3` へフォールバック） |
| `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh` | `<work_dir>/.venv` の削除 |

## venv 構築（Bash ツール経由）

venv はセッション作業領域の `workspace/.venv` に作成する（配置規約: `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv`）。

```bash
SESSION_DIR=".claude/.local/work/{yyyyMMdd_nn_summary}"
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

- 既に同一セッションで venv が構築済み（PyYAML / openpyxl 導入済み）の場合は再構築せず再利用する
- venv の Python は明示指定で使用する: `$SESSION_DIR/workspace/.venv/Scripts/python.exe`（Windows）/ `$SESSION_DIR/workspace/.venv/bin/python`（Unix）

## venv 削除（タスク完了後）

同一セッションで後続タスクが Python を使わない場合のみ削除する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```
