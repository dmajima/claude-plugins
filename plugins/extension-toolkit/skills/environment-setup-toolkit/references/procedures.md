# 実行手順詳細

`environment-setup-toolkit` の詳細実行手順。

## 動作別フロー

### setup（venv 構築）

| ステップ | 動作 |
|---------|------|
| 1 | 作業ディレクトリの確認・作成 |
| 2 | Python 実行可能性チェック（`python --version`） |
| 3 | バージョン要件があれば検証 |
| 4 | 既存 venv の有無確認 |
| 5 | venv 作成（不在時のみ） |
| 6 | pip 最新化 |
| 7 | `requirements.txt` から依存インストール |
| 8 | インストール結果のサマリ提示 |

### teardown（venv 撤去）

| ステップ | 動作 |
|---------|------|
| 1 | 削除対象 venv の存在確認 |
| 2 | 削除対象が `.claude/.local/` 配下であることを検証（誤削除防止） |
| 3 | venv ディレクトリ削除 |
| 4 | 削除確認 |

### refresh（再構築）

teardown → setup の順次実行。

### check（状態確認）

| ステップ | 動作 |
|---------|------|
| 1 | 対象 venv の存在確認 |
| 2 | Python バージョン取得 |
| 3 | `pip list` でインストール済みパッケージ取得 |
| 4 | `requirements.txt` との差分比較（あれば） |
| 5 | サマリ提示 |

## 引数仕様

呼び出し方法によって引数形式が異なる。

### Skill ツール経由（推奨、名前付き引数）

```text
Skill(skill: "environment-setup-toolkit", args: "setup --work-dir <work_dir> [--requirements <path>] [--min-python-version <ver>]")
Skill(skill: "environment-setup-toolkit", args: "teardown --work-dir <work_dir>")
```

| 名前付き引数 | 対象動作 | 必須 | 内容 |
|-----------|--------|------|------|
| `--work-dir` | setup / teardown | 必須 | 作業ディレクトリ（`.venv` の親ディレクトリ） |
| `--requirements` | setup | 任意 | requirements.txt のパス（省略時は依存インストールをスキップ） |
| `--min-python-version` | setup | 任意 | 最小 Python バージョン要件（例: `3.10`） |

### シェル直叩き（プラグイン同梱配布時のみ動作、Bash）

ADR-024 に基づき、setup スクリプトは **対象プラグインの `references/scripts/setup/`** に配置されている。`environment-setup-toolkit` 自身は実スクリプトを保有しない。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \
  -WorkDir <work_dir> [-RequirementsPath <path>] [-MinPythonVersion <ver>]
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/teardown_venv.sh" \
  -WorkDir <work_dir>
```
名前付きパラメータを使用するため、`-RequirementsPath` を省略して `-MinPythonVersion` だけ指定することができる:

```bash
bash setup_venv.sh -WorkDir "$WorkDir" -MinPythonVersion "3.10"
```
## 各 *-toolkit スキルからの利用

各スキルは **環境構築の手順詳細を本スキルに委譲** する。SKILL.md / references で以下のように参照する:

```markdown
## 環境構築

Python 利用時は `environment-setup-toolkit` スキルに委譲する。**`Skill` ツール経由を第一推奨**（配置形態に依存しないため）:

\`\`\`text
Skill(skill: "environment-setup-toolkit", args: "setup --work-dir <work_dir> --requirements <requirements>")
\`\`\`

直接スクリプト呼び出しが必要な場合（プラグイン同梱配布時のみ動作、Bash 経由）:

\`\`\`bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" \\
  -WorkDir "$WorkDir" \\
  -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"
\`\`\`


`$env:CLAUDE_PLUGIN_ROOT` は **当該プラグイン由来のスキル/コマンド/フック実行時のみ** Claude Code が解決する。スタンドアロン配布のスキル（`<repo>/.claude/skills/{name}/` 等）からは未定義となるため `Skill` ツール経由を選ぶこと。
```

## requirements.txt の配置（ADR-024）

`requirements.txt` はプラグイン単位で 1 つ、`plugins/{name}/references/scripts/setup/requirements.txt` に統合する。スキル固有のスクリプトが利用する依存もここに含める。スキルごとの個別 `requirements.txt` は禁止:

```
plugins/{plugin-name}/
├── references/
│   └── scripts/
│       └── setup/
│           ├── setup_venv.sh
│           ├── teardown_venv.sh
│           └── requirements.txt    # 全スキルの依存をマージ
└── skills/
    └── {skill-name}/
        └── references/
            └── scripts/
                └── {業務}/         # スキル固有スクリプト（依存はプラグイン直下に統合）
                    └── ...
```

## 環境構築可否のチェック

setup 実行前のチェック項目:

| 項目 | チェック内容 | 失敗時 |
|-----|------------|--------|
| Python | `python3` または `python` が PATH に存在 | エラー終了、インストール案内 |
| Python バージョン | `>=3.10` 等の指定があれば `setup_venv.sh` 内で検証 | スクリプトは fail-closed（exit 1）。続行が必要な場合、スキルが事前に Claude コンテキストでバージョンを取得し `AskUserQuestion` でユーザ確認のうえ、`-MinPythonVersion` を渡さずに呼ぶ判断を行う |
| 作業ディレクトリ | 書き込み可能 | エラー終了 |
| ディスク空き容量 | 200MB 以上推奨 | 警告 |
| 既存 venv | 既存があれば再利用 or refresh | ユーザ確認 |

**Python コマンドの解決順序（setup_venv.sh 内）**: `python` → `python3` → `py` の順で `-m venv --help` の実行可否を検証して候補を採用する。pyenv-win 環境では `python3` shim が `-m venv` 実行時に WinError 2 を返す既知の問題があるため、`python` を優先候補としている。すべて利用不可の場合はエラー終了。

**バージョン引数の安全性**: `-MinPythonVersion` は `^[0-9]+(\.[0-9]+){0,2}$` の正規表現でバリデーションされ、Python 側へは環境変数経由で渡される（PowerShell 文字列補間によるコード注入を排除）。

## 失敗時のリカバリ

| 失敗 | リカバリ |
|-----|---------|
| pip インストール失敗 | エラーログ提示、依存解決の手動修正案内 |
| Python バージョン不適合 | `pyenv` 等での切替案内 |
| 作業ディレクトリ書込不可 | パーミッション確認案内 |
| venv 作成失敗 | システム Python の `venv` モジュール有無確認 |

## 進捗管理との統合

進捗管理ファイル（`progress.md`）に環境構築のステータスを反映する:

```markdown
| # | タスク内容 | 担当者 | ステータス | メモ |
|---|-----------|-------|-----------|------|
| N | venv 構築 | environment-setup-toolkit | DONE | .venv 作成完了、5 packages installed |
```

## 完了チェックリスト

[`../../../references/checklists/completion-checklist.md`](../../../references/checklists/completion-checklist.md) に従い、作業完了報告前に自己検証を実施する。

特に重要な項目:

- [ ] venv が期待どおりの場所に作成されている
- [ ] requirements.txt の全パッケージがインストール済み
- [ ] パッケージのバージョンが範囲内
- [ ] 作業ディレクトリの想定外の場所に副作用がない
