# test-run-performance evals

本ディレクトリは `test-run-performance` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / `references/performance-execution.md` / `${CLAUDE_PLUGIN_ROOT}/references/`）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 |
|------|-----------|------------|
| 01 | case-01_response_time_pass.md | 応答時間が閾値内で pass（3 回計測・中央値採用） |
| 02 | case-02_threshold_exceeded_fail.md | 閾値超過で fail（extras.measured_value / threshold 記録・severity バンド判定） |
| 03 | case-03_load_tool_absent_skipped.md | 負荷ツール未検出 → 多重負荷ケースを skipped（単一計測は実施） |
| 04 | case-04_load_tool_detected_conditional.md | 負荷ツール検出 → 多重負荷を条件付き実行（スコープ境界の遵守） |
| 05 | case-05_mcp_unavailable_skipped.md | Playwright MCP 未ロード → 単一計測・多重負荷とも skipped（負荷ツール未検出とは別要因） |
| 06 | case-06_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 |
| 07 | case-07_response_timeout_blocked.md | 応答が得られずタイムアウト → blocked（閾値超過 fail との判定分岐） |
| 08 | case-08_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録） |
| 09 | case-09_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-08 の対） |

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

- 本スキルの実行結果は中間データとして返却するのみで、`test-results.yaml` への書き込みはオーケストレータ `test` が行う。evals は「返却する中間結果 JSON の内容」と「計測・判定の判断」を検証対象とする
- 実測値は中央値を採用し、severity は閾値超過率バンド（severity-policy.md 4.1）で判定する
