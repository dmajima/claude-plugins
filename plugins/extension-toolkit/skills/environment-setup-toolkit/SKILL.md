---
name: environment-setup-toolkit
description: Claude Code プラグインの Python venv・依存パッケージを構築・撤去するオーケストレータ。対象プラグインの venv スクリプト（references/scripts/setup/）を起動する。「venv 作って」「Python 環境セットアップ」「環境を片付けて」等で起動する。Use when setting up or tearing down a Python venv for a plugin. SKIP when authoring skill/plugin/command/agent/hook bodies (skill/plugin/command/agent/hook-toolkit) or MIT LICENSE setup (mit-license-toolkit).
---

# Environment Setup Toolkit

プラグイン単位 Python venv の **オーケストレータ** スキル（ADR-024）。本スキルは自前で setup ロジックを保持せず、対象プラグインの `references/scripts/setup/setup_venv.sh` / `teardown_venv.sh` を起動する。

## 責務

- 対象プラグインの `references/scripts/setup/setup_venv.sh` の起動（venv 構築 + 依存インストール）
- 対象プラグインの `references/scripts/setup/teardown_venv.sh` の起動（venv 削除）
- プラグインに setup スクリプトが未配置の場合の **作成案内**（ADR-024 準拠の雛形提示）
- 環境構築可否の事前チェック（Python バージョン確認等）
- 環境変数の設定支援（必要時）

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| スキル本体の生成 | `skill-toolkit` |
| プラグイン外形 | `plugin-toolkit` |
| コマンド・エージェント・フック・README 生成 | 各 `*-toolkit` |
| マーケットプレイス公開 | `marketplace-publisher` |

## トリガー条件

- 「venv 作って」「Python 環境セットアップ」「Python 仮想環境構築」
- 「`{skill}` スキルの venv 構築」「`{plugin}` プラグインの環境セットアップ」
- 「環境を片付けて」「venv 削除」「teardown」
- 「依存パッケージをインストール」

このスキルを起動しないケース:

- 「スキル本体を作って」（→ `skill-toolkit`）
- 「フックを設定」（→ `hook-toolkit`）

## 前提

- 作業ディレクトリ（venv 配置先）が決まっているか、対話で確定可能
- Python が利用可能（事前チェック）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、または引数で全パラメータ指定 | 非対話 | デフォルト値・引数値で確定し進行 |
| 上記以外 | 対話 | 不足パラメータをユーザに確認 |

## 実行フロー

### 1. 動作判定

| ユーザ要求 | アクション |
|----------|----------|
| 構築（setup） | venv 作成 + 依存インストール |
| 撤去（teardown） | venv 削除 |
| 再構築（refresh） | teardown + setup |
| チェック（check） | 既存 venv の状態確認 |

### 2. パラメータ確定

| パラメータ | 必須 | 例 |
|----------|------|---|
| 動作（setup / teardown / refresh / check） | 必須 | `setup` |
| 作業ディレクトリ | 必須 | `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace` |
| `requirements.txt` の場所 | setup 時任意 | プラグイン直下 `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt`（ADR-024）。省略時は依存インストールをスキップ |
| Python バージョン要件 | 任意 | `>=3.10` |

### 3. 環境チェック

| チェック | 失敗時の動作 |
|---------|----------|
| Python の存在 | エラー終了 + インストール案内 |
| Python バージョン要件 | スクリプトは fail-closed（即時 exit 1）。続行が必要な場合、呼び出し側スキルが事前に Claude コンテキストでバージョンを照会し、`AskUserQuestion` で続行可否をユーザ確認のうえ、要件不適合のままスクリプトを呼ばない判断を行う |
| 作業ディレクトリの存在 | 自動作成（or 確認後作成） |
| 既存 venv の有無 | setup 時は再利用、refresh 時は teardown 後に新規作成 |

詳細は [references/procedures.md](references/procedures.md) を参照。

### 4. setup 実行

対象プラグインの `references/scripts/setup/setup_venv.sh` を起動する（プラグイン単位 venv、ADR-024）:

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \
  -WorkDir <work_dir> \
  -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt" \
  [-MinPythonVersion <ver>]
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.ps1" `
  -WorkDir <work_dir> `
  -RequirementsPath "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt" `
  [-MinPythonVersion <ver>]
```

</details>

| 引数 | 必須 | 内容 |
|-----|------|------|
| `-WorkDir` | 必須 | 作業ディレクトリ（`.venv` の親） |
| `-RequirementsPath` | 任意 | requirements.txt のパス（省略時は依存インストールをスキップ） |
| `-MinPythonVersion` | 任意 | 最小 Python バージョン要件（例: `3.10`）。未指定時はバージョンチェックなし |

スクリプトの動作:

1. （指定があれば）システム Python バージョン要件を検証
2. `<work_dir>/.venv` 不在なら作成
3. pip / setuptools / wheel を最新化
4. `-RequirementsPath` 指定時のみ依存をインストール

### 5. teardown 実行

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" -WorkDir <work_dir>
```

<details><summary>PowerShell フォールバック</summary>

```powershell
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.ps1" -WorkDir <work_dir>
```

</details>

`<work_dir>/.venv` を削除。

### 5.5 プラグインに setup スクリプトが未配置の場合

ADR-024 準拠の雛形を作成するよう案内する:

| ファイル | 配置先 |
|--------|--------|
| `setup_venv.sh` | `plugins/{name}/references/scripts/setup/setup_venv.sh` |
| `teardown_venv.sh` | `plugins/{name}/references/scripts/setup/teardown_venv.sh` |
| `requirements.txt` | `plugins/{name}/references/scripts/setup/requirements.txt` |

雛形は `extension-toolkit` プラグイン自身の `references/scripts/setup/` を参考にする。

### 6. 検証

- [ ] Python 実行可能（`python --version` 成功）
- [ ] venv ディレクトリが期待どおり存在 / 不在
- [ ] 依存パッケージのインポート確認（setup 時）
- [ ] 作業ログを進捗管理ファイルに反映
- [ ] [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証

### 7. 引き渡し

**作業完了報告の前に**: [`../../references/completion-checklist.md`](../../references/completion-checklist.md) 節 2.4 に従い、setup/teardown/refresh/check のいずれも実コマンド実行で動作確認し、`AskUserQuestion` で承認を取得する（ADR-032）。venv 操作は副作用がディスクに残るためデモは特に重要。

| 状況 | 提示内容 |
|-----|---------|
| setup 完了 | venv パス / 利用方法（`python` 実行例） |
| teardown 完了 | 削除確認 |
| refresh 完了 | 新 venv パス + 旧 venv の削除確認 |
| check 完了 | 既存 venv 状態（バージョン / インストール済パッケージ一覧） |

## 重要な制約

- venv の作成先は **必ずセッション作業領域** （`.claude/.local/work/{...}/workspace/.venv`）
- システムインタープリタへのパッケージインストール禁止
- スキル/プラグインのソースディレクトリ（`scripts/` 等）に venv を作らない
- ユーザシェル環境の永続変数（`.bashrc` 等）への書き込み禁止
- パスポータビリティチェック必須（[`../../references/path-portability.md`](../../references/path-portability.md)）
- 利用者環境非依存性の維持（[`../../references/self-containment.md`](../../references/self-containment.md)、ADR-022）
- 第三者レビュー起動時はフレッシュ Agent インスタンスで起動（[`../../references/review-freshness.md`](../../references/review-freshness.md)、ADR-021）
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md) + [`../../references/askquestion-strategy.md`](../../references/askquestion-strategy.md)）
- 生成・改修するスクリプトは Bash 標準方針 (`~/.claude/rules/tools/shell-preference.md`) に従う。PowerShell フォールバック実装も併せて生成する場合は [`../../references/powershell-pitfalls.md`](../../references/powershell-pitfalls.md) の落とし穴を回避する
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1） |
| 完了チェックリスト | [`../../references/completion-checklist.md`](../../references/completion-checklist.md) |
| 詳細手順 | [`references/procedures.md`](references/procedures.md) |
| Python venv 仕様 | [`references/python-venv.md`](references/python-venv.md) |
| 動作例 | [`evals/`](evals/) |
