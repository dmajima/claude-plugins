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
| 09 | case-09_playwright_test_run.md | automation: playwright-test × `npx playwright test` 実走 pass（認証・シードフィクスチャで system シナリオを再現可能に実走し全 pass を記録・executed_by: playwright-test・MCP 経路と併存） | system / uat |
| 10 | case-10_playwright_test_skipped.md | automation: playwright-test だが Playwright/ランナー・fixtures.yaml/SUT テストコード不在 → skipped + reason（実走前提の欠如・MCP 未ロード skipped〔case-05〕とは別前提） | system / uat |
| 11 | case-11_exploratory_session.md | automation: exploratory × 対話（チャーター提示 → タイムボックス案内 → セッション聴取 → セッションシート evidence 化 → session_findings 付き human-assisted 記録） | uat |
| 12 | case-12_exploratory_non_interactive.md | automation: exploratory × 非対話（実行せず skipped + reason に manual-sheet= 受領のチャーターシートパスを転記。case-11 の対） | uat |
| 13 | case-13_manual_assist_defer_to_sheet.md | automation: manual-assist × 対話で「後で実施」選択（オンデマンド手順書生成〔オーケストレータの責務〕→ skipped + reason に手順書パス転記） | system / uat |
| 14 | case-14_exploratory_blocked_or_defer.md | automation: exploratory × 対話でセッション開始不能 → blocked + reason（副分岐: 「後で実施」= チャーターシート縮退 / 「中止」= 実施せず記録もしない） | uat |

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
- `automation: playwright-test`（`npx playwright test` 実走）経路は case-09（全 pass）/ case-10（実走前提不在の skipped）で扱い、MCP 経路（`automation: playwright`）と併存する分岐を検証する
- 手動 / 探索の軸: `automation: manual-assist`（case-07 / 08 / 13）と `exploratory`（チャーターベース人間セッション。case-11 / 12 / 14）は対話 = human-assisted 記録・非対話 = 手順書（チャーターシート）縮退の skipped を対で検証する（規範は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md`）。対話の「後で実施」縮退は case-13（manual-assist）と case-14 副分岐（exploratory）が扱う
- exploratory の結果終端はスキル横断で対応する（pass = case-11 / fail = test-run-functional evals case-12 / blocked = case-14）
