# test-run-scenario evals

本ディレクトリは `test-run-scenario` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / `references/scenario-execution.md` / `${CLAUDE_PLUGIN_ROOT}/references/`）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | レベル |
|------|-----------|------------|-------|
| 01 | case-01_system_scenario_pass.md | 業務シナリオを通しで実行し全ステップ pass（system） | system |
| 02 | case-02_midway_fail_downstream_blocked.md | シナリオ途中でステップ fail → ケース fail・依存する後続ケースを blocked | system |
| 03 | case-03_uat_finding_user_impact.md | UAT 観点の指摘（fail + ユーザー影響記載・受入判断は人間） | uat |
| 04 | case-04_interrupted_progress.md | 長大シナリオの中断（進行状況を actual に記録・scope 全件返却） | system |
| 05 | case-05_mcp_unloaded_skipped.md | Playwright MCP 未ロード検出（偽装せず skipped + reason で返却） | system / uat |
| 06 | case-06_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 | 単独 |
| 07 | case-07_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録） | system / uat |
| 08 | case-08_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-07 の対） | system / uat |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args（target-slug / run_id / ケースリスト / アプリ情報）・前提 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・セクションを明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（スキルの「引き渡し」フォーマットへの参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 注記

- 本スキルの実行結果は中間データとして返却するのみで、`test-results.yaml` への書き込みはオーケストレータ `test` が行う。evals は「返却する中間結果 JSON の内容」と「実行中の判断」を検証対象とする
- 対話/非対話モードの確認・実績記録・ゲート判定はオーケストレータの責務のため、実行スキル単体の evals では扱わない
