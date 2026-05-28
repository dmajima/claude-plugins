# 環境構築

このファイルはスキル `{skill-name}` が動作するための環境構築手順を記述する。Python venv 等の構築は `environment-setup-toolkit` スキルに委譲する（責務の単一化、ADR-024）。

## 依存パッケージの登録先（ADR-024）

スキルが利用する Python 依存パッケージは、**プラグイン直下** の `references/scripts/setup/requirements.txt` に統合する。スキルごとの個別 `requirements.txt` は禁止。

```text
plugins/{plugin-name}/references/scripts/setup/requirements.txt
```

このスキルが新規パッケージを必要とする場合は、上記ファイルに追記する（既存依存と競合しないか確認）。

## venv 構築手順

`environment-setup-toolkit` を **`Skill` ツール経由で呼び出す** のを第一推奨とする。スキルがどう配布されているか（プラグイン同梱 / スタンドアロン）に依存せず動作する:

```text
Skill(skill: "environment-setup-toolkit", args: "setup --work-dir <work_dir> --requirements ${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt")
```

`Skill` ツールが利用できない場面でのみ直接スクリプト呼び出しを検討する:

| 配置先 | 呼び出し例 | 備考 |
|-------|----------|------|
| プラグイン同梱（同一プラグイン由来） | `bash "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/setup_venv.sh" -WorkDir "<work_dir>" -RequirementsPath "$CLAUDE_PLUGIN_ROOT/references/scripts/setup/requirements.txt"` (PowerShell フォールバック: `pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.ps1" ...`) | `$CLAUDE_PLUGIN_ROOT` は同プラグイン由来のスキル/コマンド/フック実行時に Claude Code が解決（Bash 標準、shell-preference.md 準拠） |
| スタンドアロン（`<repo>/.claude/skills/{name}/`、または `~/.claude/skills/{name}/`） | 直接呼び出し不可。`Skill` ツール経由のみ | `${CLAUDE_PLUGIN_ROOT}` が未定義のため。プラグイン非依存の単体スキルは Skill ツール経由を必須とする |

`<work_dir>` は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/` を推奨する。グローバルルール `~/.claude/rules/claude/work-directory.md` は **存在すれば追加参照** として有用だが必須ではない（ADR-022、不在時は上記推奨のみで動作）。

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

| 用途 | ファイル（テンプレート配備後は相対パスで解決される） |
|-----|---------|
| スクリプト記述・配置ポリシー | `${CLAUDE_PLUGIN_ROOT}/references/scripts-policy.md`（プラグイン直下） |
| 環境構築スキル | `environment-setup-toolkit`（同一プラグイン内、配備後は `../../environment-setup-toolkit/`） |
| Python venv 仕様 | `environment-setup-toolkit/references/python-venv.md`（配備後は `../../environment-setup-toolkit/references/python-venv.md`） |

> **テンプレートファイル注記**: 本ファイルはテンプレート格納場所（`references/templates/skill/references/`）にあるため、相対リンクの起点が配備先（`skills/{name}/references/`）と異なる。テンプレート展開時に配備先からの正しい相対パス（`../../environment-setup-toolkit/...`）に置換される前提で、ここでは平文表記とする。
