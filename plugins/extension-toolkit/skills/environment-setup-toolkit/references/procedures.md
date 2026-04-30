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

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/python/setup_venv.sh" <work_dir> [<requirements_path>]
bash "${CLAUDE_SKILL_DIR}/scripts/python/teardown_venv.sh" <work_dir>
```

| 引数 | 必須 | 内容 |
|-----|------|------|
| `<work_dir>` | 必須 | 作業ディレクトリ（`.venv` の親ディレクトリ） |
| `<requirements_path>` | setup 任意 | requirements.txt のパス（省略時は依存インストールしない） |

## 各 *-toolkit スキルからの利用

各スキルは **環境構築の手順詳細を本スキルに委譲** する。SKILL.md / references で以下のように参照する:

```markdown
## 環境構築

Python 利用時は `environment-setup-toolkit` スキルに委譲する。**`Skill` ツール経由を第一推奨**（配置形態に依存しないため）:

\`\`\`text
Skill(skill: "environment-setup-toolkit", args: "setup --work-dir <work_dir> --requirements <requirements>")
\`\`\`

直接スクリプト呼び出しが必要な場合（プラグイン同梱配布時のみ動作）:

\`\`\`bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/environment-setup-toolkit/scripts/python/setup_venv.sh" <work_dir> <requirements>
\`\`\`

`${CLAUDE_PLUGIN_ROOT}` は **当該プラグイン由来のスキル/コマンド/フック実行時のみ** Claude Code が解決する。スタンドアロン配布のスキル（`<repo>/.claude/skills/{name}/` 等）からは未定義となるため `Skill` ツール経由を選ぶこと。
```

## requirements.txt の配置

各スキルが固有の依存を持つ場合、そのスキル内の `references/setup.md` または `scripts/` 配下に `requirements.txt` を置き、`environment-setup-toolkit` 呼び出し時にパスを渡す。

```
plugins/extension-toolkit/skills/{skill-name}/
├── SKILL.md
└── references/
    └── setup.md           # 依存パッケージリスト・インストール手順を文書化
```

または:

```
plugins/extension-toolkit/skills/{skill-name}/
└── scripts/
    └── deps/
        └── requirements.txt
```

## 環境構築可否のチェック

setup 実行前のチェック項目:

| 項目 | チェック内容 | 失敗時 |
|-----|------------|--------|
| Python | `python --version` が成功 | エラー終了、インストール案内 |
| Python バージョン | `>=3.10` 等の指定があれば検証 | 警告 + ユーザ確認 |
| 作業ディレクトリ | 書き込み可能 | エラー終了 |
| ディスク空き容量 | 200MB 以上推奨 | 警告 |
| 既存 venv | 既存があれば再利用 or refresh | ユーザ確認 |

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

[`../../../references/completion-checklist.md`](../../../references/completion-checklist.md) に従い、作業完了報告前に自己検証を実施する。

特に重要な項目:

- [ ] venv が期待どおりの場所に作成されている
- [ ] requirements.txt の全パッケージがインストール済み
- [ ] パッケージのバージョンが範囲内
- [ ] 作業ディレクトリの想定外の場所に副作用がない
