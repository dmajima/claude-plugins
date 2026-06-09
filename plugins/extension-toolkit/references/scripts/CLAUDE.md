# scripts/

プラグイン横断の **実行可能スクリプト** を管理する（ADR-025）。

## ファイル一覧

| サブフォルダ | 内容 |
|------------|------|
| `setup/` | venv 構築・削除スクリプト（`setup_venv.sh` / `teardown_venv.sh` / `requirements.txt`） |
| `hooks/` | プラグイン同梱フックスクリプト（`check_version_bump.sh` / `check_version_bump_on_commit.sh` / `enforce_toolkit_routing.sh`） |
| `evals/` | evals 実行エンジン（`run_evals.py`） |

## 利用ルール

- 実行スクリプトは `references/scripts/` 配下にのみ配置する。プラグイン直下・スキル直下の `scripts/` は禁止（ADR-025）
- シェルスクリプトは Bash（`.sh`）標準。PowerShell はフォールバック適用時のみ
- venv 関連はプラグイン単位で統合する。スキルごとの個別 `requirements.txt` は禁止（ADR-024）
- フックスクリプトはフェイルオープン設計（exit 0）を必須とする
- Python スクリプトは `sys.stdout.reconfigure(encoding='utf-8')` を先頭に含める

## 関連フォルダ

- `setup/` の `requirements.txt` は全スキルの依存をマージしたもの
- `hooks/` のスクリプトは `../../hooks/hooks.json` から参照される
