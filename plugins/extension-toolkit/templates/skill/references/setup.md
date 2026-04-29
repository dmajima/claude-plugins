# 環境構築

このファイルはスキル `{skill-name}` が動作するための環境構築手順を記述する。

## Python 利用時の必須スクリプト

`scripts/setup/` に以下を配置する:

| ファイル | 役割 |
|---------|------|
| `requirements.txt` | 依存パッケージの定義（バージョン固定推奨） |
| `setup_venv.sh` | `<work_dir>/.venv` に venv 作成 + パッケージインストール |
| `teardown_venv.sh` | `<work_dir>/.venv` を削除 |

## 依存パッケージ

```text
{パッケージ名 1}=={バージョン}
{パッケージ名 2}=={バージョン}
```

## venv 構築手順

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" "<work_dir>"
```

`<work_dir>` は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/` を推奨する（`~/.claude/rules/claude/work-directory.md` を参照）。

## venv 削除手順

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" "<work_dir>"
```

## 動作確認

```bash
"<work_dir>/.venv/Scripts/python" -c "import {package}; print({package}.__version__)"
```
