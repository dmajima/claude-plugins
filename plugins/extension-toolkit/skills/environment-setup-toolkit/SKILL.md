---
name: environment-setup-toolkit
description: Claude Code のスキル/プラグインの実行環境（Python venv・依存パッケージ・環境変数）を構築・撤去するスキル。「venv 作って」「Python 環境セットアップ」「foo スキルの venv 構築」「環境を片付けて」などの依頼で起動する。Use when the user wants to create, refresh, or tear down a Python virtual environment for a skill or plugin's working directory. SKIP when the user wants to build skill body, plugin shell, command, agent, or hook (use the corresponding *-toolkit).
---

# Environment Setup Toolkit

スキル / プラグインの実行環境を **一元的に構築・撤去** するスキル。各 `*-toolkit` スキルは Python 環境構築の手順を本スキルに委譲することで、責務を単一化する。

## 責務

- セッション作業領域への Python venv 作成・再利用判定
- `requirements.txt` ベースの依存パッケージインストール
- venv の撤去（タスク終了後のクリーンアップ）
- 環境変数の設定支援（必要時）
- 環境構築可否の事前チェック（Python バージョン確認等）

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
| `requirements.txt` の場所 | setup 時必須 | スキル内 `${CLAUDE_SKILL_DIR}/scripts/setup/requirements.txt` |
| Python バージョン要件 | 任意 | `>=3.10` |

### 3. 環境チェック

| チェック | 失敗時の動作 |
|---------|----------|
| Python の存在 | エラー終了 + インストール案内 |
| Python バージョン要件 | 警告 + 続行可否をユーザに確認 |
| 作業ディレクトリの存在 | 自動作成（or 確認後作成） |
| 既存 venv の有無 | setup 時は再利用、refresh 時は teardown 後に新規作成 |

詳細は [references/procedures.md](references/procedures.md) を参照。

### 4. setup 実行

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/python/setup_venv.sh" <work_dir> <requirements_path>
```

スクリプトの動作:

1. `<work_dir>/.venv` 不在なら作成
2. pip を最新化
3. `<requirements_path>` の依存をインストール

### 5. teardown 実行

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/python/teardown_venv.sh" <work_dir>
```

`<work_dir>/.venv` を削除。

### 6. 検証

- [ ] Python 実行可能（`python --version` 成功）
- [ ] venv ディレクトリが期待どおり存在 / 不在
- [ ] 依存パッケージのインポート確認（setup 時）
- [ ] 作業ログを進捗管理ファイルに反映
- [ ] [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証

### 7. 引き渡し

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
