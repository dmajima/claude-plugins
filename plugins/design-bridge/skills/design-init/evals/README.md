# Evals: design-init

このディレクトリは `design-init` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| [case-01](case-01_new_setup_interactive.md) | 未導入リポジトリへの新規導入（対話モード・候補複数から選択） | 実行モード判定 = 対話 + 実行フロー 2 の「候補が複数」 |
| [case-02](case-02_new_setup_non_interactive.md) | 未導入リポジトリへの新規導入（非対話モード） | 実行モード判定 = 非対話（`--non-interactive` / projectId 指定） |
| [case-03](case-03_existing_config_update.md) | 導入済みリポジトリでの再実行（更新モード・差分提示） | 実行フロー 1 の「既に `.claude/design-bridge.json` がある」 |
| [case-04](case-04_design_auth_error.md) | design-system 未認可で `list_projects` が認可エラー（中断） | 実行フロー 2 の「`list_projects` が認可エラーを返した場合」 |

## カバレッジ対応

| 必須カバレッジ | 対応ケース |
|--------------|----------|
| 対話モード | case-01 / case-03 |
| 非対話モード | case-02 |
| 主要分岐の各ブランチ | case-01（新規）/ case-03（更新） |
| エラー系（既知） | case-04 |

実行フロー 2 の「候補が 1 件」「候補が 0 件（新規作成）」、および `get_project` の型判定で design-system でないと分かった場合の扱いは、case-01 の「分岐の根拠」「関連ケース」で同じフェーズの兄弟分岐として記述している。`jq` 不在時の続行可否確認は case-02 で扱う。

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。

本スキルは `DesignSync` によるリモート状態と対象リポジトリの状態に依存する AI 主導スキルのため、自動実行スクリプト（`demo.sh`）は適用外とし、目視確認を基本とする。生成された `.claude/design-bridge.json` の妥当性は [`../references/config-schema.md`](../references/config-schema.md) のフィールド表と突き合わせて確認する。

## ケース追加ルール

新しい分岐ロジックを追加した時は、対応するケースファイル（`case-{2 桁番号}_{snake_case 名}.md`）を必ず追加し、本一覧表を同期する。各ケースには「分岐の根拠」「関連ケース」セクションを含める。
