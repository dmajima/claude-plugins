# connector references/scripts/setup/

connector プラグイン共通の venv ライフサイクル管理スクリプト（ADR-024: プラグイン単位 1 venv）。

## 目的と範囲

Python を使用するスキル（ailead / projectboard）が共有するセッション venv の構築・削除と、全スキルの依存を統合した requirements を管理する。スキル個別の venv・requirements.txt は作らない。

## ファイル一覧

| ファイル | 用途 |
|---------|------|
| [setup_venv.sh](setup_venv.sh) | `<WORK_DIR>/.venv` の構築 + 依存インストール（引数: WORK_DIR） |
| [teardown_venv.sh](teardown_venv.sh) | `<WORK_DIR>/.venv` の削除（引数: WORK_DIR） |
| [requirements.txt](requirements.txt) | 全スキルの依存の統合リスト（ailead: requests / projectboard: 依存なし） |

## 利用ルール

- 各スキルは本スクリプトを呼び出すだけ（独自に venv を作成・破棄しない）
- venv の配置はセッション作業領域 `<WORK_DIR>/.venv`（`.claude/.local/work/{session}/workspace/.venv`）
- 依存を追加する場合は requirements.txt に追記し、由来スキルをコメントで明記する
