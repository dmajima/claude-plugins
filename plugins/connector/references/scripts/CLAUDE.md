# connector references/scripts/

connector プラグイン共通の実行可能スクリプト（ADR-024 / ADR-025）。スキル固有スクリプトは各 `skills/{skill}/references/scripts/` 配下にある。

## 目的と範囲

全スキルから参照されるプラグイン共通処理（venv 構築・認証情報の照合/保存・PowerShell ツール経由の Python 起動）を集約する。ドキュメント（`*.md`）への実装コードのインライン記載を避け、呼び出し例のみをドキュメントに残す。

## 原則

1. **venv はプラグイン単位で 1 つ**（ADR-024）: `setup/` の 3 ファイル（`setup_venv.sh` / `teardown_venv.sh` / `requirements.txt`）でライフサイクルを管理する。スキル個別の venv・requirements.txt を作らない
2. **認証情報の値を stdout 以外に出さない**: `credentials/` のスクリプトは値を標準出力にのみ返す。会話・ログへの転記はマスク必須（`../credentials-precheck.md` セクション 4.3）
3. **仕様は SSOT 側に置く**: ストア一覧・保存先決定ルールは `../credentials-precheck.md`（セクション 2.1 / 4.5）が正典。スクリプトはその実装

## ナビゲーション

| スクリプト | 用途 | 仕様（SSOT） |
|-----------|------|-------------|
| [setup/setup_venv.sh](setup/setup_venv.sh) / [setup/teardown_venv.sh](setup/teardown_venv.sh) | セッション作業領域への venv 構築・削除 | 各スキルの `references/setup.md` |
| [setup/requirements.txt](setup/requirements.txt) | 全スキルの依存の統合リスト | ADR-024 |
| [credentials/cred_lookup.sh](credentials/cred_lookup.sh) | 認証情報ストアの列挙・横断照合（`--list-stores` / `--domain` / `--entry`） | `../credentials-precheck.md` セクション 2.1 |
| [credentials/cred_save.sh](credentials/cred_save.sh) | 対話取得フォールバック「保存する」の保存処理（保存先決定 + jq マージ） | `../credentials-precheck.md` セクション 4.5 |
| [run_via_job.sh](run_via_job.sh) | PowerShell ツール経由で Python を起動する際の Start-Job ラッパー | グローバルルール `python-subprocess-hang-windows.md` |
