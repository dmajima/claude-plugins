# 環境構築

このファイルはスキル `{skill-name}` が動作するための環境構築手順を記述する。Python venv 等の構築は `environment-setup-toolkit` スキルに委譲する（責務の単一化）。

## 依存パッケージ

```text
{パッケージ名 1}=={バージョン}
{パッケージ名 2}=={バージョン}
```

これらをスキル内 `references/setup.md` に列挙し、または `scripts/deps/requirements.txt` として保管する。

## venv 構築手順

`environment-setup-toolkit` を **`Skill` ツール経由で呼び出す** のを第一推奨とする。スキルがどう配布されているか（プラグイン同梱 / スタンドアロン）に依存せず動作する:

```text
Skill(skill: "environment-setup-toolkit", args: "setup --work-dir <work_dir> --requirements ${CLAUDE_SKILL_DIR}/scripts/deps/requirements.txt")
```

`Skill` ツールが利用できない場面でのみ直接スクリプト呼び出しを検討する。配置先により呼び出し方法が異なる:

| 配置先 | 呼び出し例 | 備考 |
|-------|----------|------|
| プラグイン同梱（`extension-toolkit` インストール済） | `bash "${CLAUDE_PLUGIN_ROOT}/skills/environment-setup-toolkit/scripts/python/setup_venv.sh" "<work_dir>" "${CLAUDE_SKILL_DIR}/scripts/deps/requirements.txt"` | `${CLAUDE_PLUGIN_ROOT}` は同プラグイン由来のスキル/コマンド/フック実行時に Claude Code が解決 |
| スタンドアロン（`<repo>/.claude/skills/{name}/`、または `~/.claude/skills/{name}/`） | 直接呼び出し不可。`Skill` ツール経由のみ | `${CLAUDE_PLUGIN_ROOT}` が未定義のため。プラグイン非依存の単体スキルは Skill ツール経由を必須とする |

`<work_dir>` は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/` を推奨する（`~/.claude/rules/claude/work-directory.md` を参照）。

## venv 削除手順

```text
Skill(skill: "environment-setup-toolkit", args: "teardown --work-dir <work_dir>")
```

## 動作確認

```bash
"<work_dir>/.venv/Scripts/python" -c "import {package}; print({package}.__version__)"
```

## このスキル固有の追加手順

（必要に応じて記載。設定ファイル・環境変数・初期データなど）

## 参照

| 用途 | ファイル |
|-----|---------|
| 環境構築スキル | [`environment-setup-toolkit`](../../../environment-setup-toolkit/) |
| Python venv 仕様 | [`environment-setup-toolkit/references/python-venv.md`](../../../environment-setup-toolkit/references/python-venv.md) |
