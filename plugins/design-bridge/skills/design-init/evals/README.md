# Evals: design-init

このディレクトリは `design-init` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| [case-01](case-01_new_setup_interactive.md) | 未導入リポジトリへの新規導入（対話モード・候補複数から選択・Chromium は `--skip-browser` で後回し） | 実行モード判定 = 対話 + 実行フロー 2 の「候補が複数」 |
| [case-02](case-02_new_setup_non_interactive.md) | 未導入リポジトリへの新規導入（非対話モード・`jq` 不在のまま続行） | 実行モード判定 = 非対話（`--non-interactive` / projectId 指定）+ 実行フロー 1 の `jq` 検査 NG |
| [case-03](case-03_existing_config_update.md) | 導入済みリポジトリでの再実行（更新モード・差分提示・既存 venv 再利用） | 実行フロー 1 の「既に `.claude/design-bridge.json` がある」 |
| [case-04](case-04_design_auth_error.md) | design-system 未認可で `list_projects` が認可エラー（中断） | 実行フロー 2 の「`list_projects` が認可エラーを返した場合」 |
| [case-05](case-05_no_candidate_create_project.md) | 候補が 0 件。確認のうえ `create_project` で design-system プロジェクトを新規作成する | 実行フロー 2 の「候補が 0 件」 |
| [case-06](case-06_non_design_system_type.md) | 選んだプロジェクトが `get_project` で design-system 型でないと判明し、選び直す | 実行フロー 2 の `get_project` による型確認 = NG |

## カバレッジ対応

| 必須カバレッジ | 対応ケース |
|--------------|----------|
| 対話モード | case-01 / case-03 / case-05 / case-06 |
| 非対話モード | case-02 |
| 主要分岐の各ブランチ（新規 / 更新） | case-01・case-02（新規）/ case-03（更新） |
| 主要分岐の各ブランチ（プロジェクト決定） | case-01（候補が複数）/ case-05（候補が 0 件）/ case-06（型が不一致） |
| 主要分岐の各ブランチ（venv） | case-01（`--skip-browser` で後回し）/ case-02（既定どおり Chromium まで導入）/ case-03（既存 venv の再利用） |
| エラー系（既知・中断） | case-04（認可エラー） |
| エラー系（既知・続行） | case-02（`jq` 不在） |

実行フロー 2 の「候補が 1 件」は、確認の形が `AskUserQuestion` による単一確認になるだけで以降の挙動が case-01 と同一のため、case-01 の「分岐の根拠」で兄弟分岐として記述している。

### 意図的にケース化していない分岐

前提 1（git リポジトリであること）と前提 2（Python 3.9 以上が利用可能であること）の **不成立時の挙動は SKILL.md に定義が無い**。現状では中断するのか警告して続行するのかを決められないため、挙動を創作しないという方針からケース化していない。全ケースの「既存状態」はこの 2 つが満たされている前提で記述している。SKILL.md 側で NG 時の帰結（例: `jq` と同じ警告付き続行か、認可エラーと同じ中断か）が定義された時点で、本ディレクトリにケースを追加する。

## 仕様上の確認ポイント

ケース共通で、次の 5 点が満たされているかを必ず確認する。

| 観点 | 期待 |
|-----|------|
| venv の構築方法 | design-bridge 同梱の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh --project-root <path>` を使う。他プラグインへ委譲しない |
| venv の配置 | `.claude/.local/plugins/design-bridge/.venv`（永続）。セッション作業領域には作らない |
| Python 要件 | 3.9 以上 |
| `jq` の位置付け | 任意依存。不在でも導入は続行でき、`watch` 設定が読めず既定の監視対象（`specs` の `.md` / `mocks` の `.html`）へ縮退する |
| `.claude/design-bridge.json` の内容 | 構成情報のみ。`blockLimit` などブロック挙動を変える値を書かない（調整は `~/.claude/.local/plugins/design-bridge/user-config.json`）。`watch` の各エントリに `kind`（`spec` / `mock`）がある |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

本スキルは `DesignSync` によるリモート状態と対象リポジトリの状態に依存する AI 主導スキルのため、自動実行フロントマターは付与せず、目視確認を基本とする。生成された `.claude/design-bridge.json` の妥当性は [`../references/config-schema.md`](../references/config-schema.md) のフィールド表と突き合わせて確認する。

venv については、実行後に `.claude/.local/plugins/design-bridge/.venv` が存在することと、`--skip-browser` を使ったケースで Chromium の後追い手順が報告に含まれていることをファイルシステムと出力の双方で確認する。

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイル（`case-{2 桁番号}_{snake_case 名}.md`）を必ず追加し、本一覧表を同期する。各ケースには「分岐の根拠」「関連ケース」セクションを含める。
