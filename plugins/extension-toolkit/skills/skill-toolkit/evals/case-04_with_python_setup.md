# Case 04: Python 利用スキル作成（プラグイン直下 venv に依存追加）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Python を使うスキル `data-analyzer` を作って" |
| 引数 | `data-analyzer --python` |
| フラグ | `--python` |
| 既存状態 | `data-analyzer` スキルが未存在 |

## 期待動作

### Phase 1: パラメータ確認

通常のパラメータ確認に加え、プラグイン直下 `references/scripts/setup/requirements.txt` に追記すべき依存パッケージを確認。

### Phase 2: テンプレート展開

`references/templates/skill/` のうち `references/setup.md`（プラグイン直下スクリプトへの委譲記述）をコピー。**venv 構築・撤去スクリプト・スキル単位 `requirements.txt` はコピー / 作成しない**（ADR-024 によりプラグイン直下に集約）。

スキル固有の Python スクリプトが必要な場合は `references/scripts/{業務単位}/{name}.py` に配置する（ADR-025、スキル直下 `scripts/` は禁止）。

### Phase 3: 依存リスト統合

ユーザ指定の依存パッケージを **プラグイン直下** `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` に追記する（バージョン固定推奨）。`references/setup.md` の依存パッケージセクションも該当パッケージを案内する形で同期する。

#### 既存依存との競合検出（同名パッケージ別バージョン）

追記しようとしたパッケージが既存 requirements.txt に **同名で異なるバージョン** で存在する場合:

| 状況 | アクション |
|-----|---------|
| 完全一致（同名同バージョン） | スキップ（重複追加しない）|
| 同名・別バージョン | `AskUserQuestion` で 3 択提示: (1) 新版で上書き、(2) 既存版を維持、(3) 別パッケージとして並存（互換要件次第で却下推奨）|
| 範囲指定が交差しない（例: `==1.2.3` vs `>=2.0`）| 同上の 3 択 + 既存スキルへの影響を警告 |

`--non-interactive` モードでは「既存版を維持」をデフォルトとし、警告ログを残す（ユーザに対話モードでの確認を促す）。

### Phase 4: 検証

- 通常チェックに加え、プラグイン直下 `references/scripts/setup/requirements.txt` に新規依存が追加されているか
- スキル内に `requirements.txt` / `setup_venv.sh` / `teardown_venv.sh` が **配置されていない** こと（ADR-024 責務集約、Bash 標準・PowerShell フォールバック）
- スキル直下に `scripts/` ディレクトリが **存在しない** こと（ADR-025、`references/scripts/{業務}/` のみ許可）
- `references/setup.md` 内で `environment-setup-toolkit` または `${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` への委譲が明記されているか
- `procedures.md` 冒頭で `setup.md` を参照しているか

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常一式 + `references/setup.md`（必要なら `references/scripts/{業務}/*.py`）。venv スクリプトとスキル単位 requirements.txt は作らない |
| プラグイン直下への変更 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` に依存パッケージ追記 |
| 標準出力（要約） | 「`data-analyzer` スキルを作成（依存はプラグイン直下 requirements.txt に統合、venv 構築は environment-setup-toolkit に委譲）」+ 利用例 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--python` フラグの有無 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（Python なし）
