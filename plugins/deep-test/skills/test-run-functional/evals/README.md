# test-run-functional evals

本ディレクトリは `test-run-functional` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_screen_operation_pass.md | 画面操作 pass（steps 対応付け・ステップごとスクリーンショット・即時移送・照合） | 委譲 |
| 02 | case-02_display_mismatch_fail.md | 表示不一致 fail（失敗時点スクリーンショット + コンソールログ + defect 3 点セット収集） | 委譲 |
| 03 | case-03_target_url_unreachable_blocked.md | 対象 URL 不達（応答なしのままタイムアウト超過）→ blocked + reason | 委譲 |
| 04 | case-04_mcp_unavailable_skipped.md | MCP ツール不可 → scope 全ケース skipped（二重防御） | 委譲 |
| 05 | case-05_dependency_fail_blocked.md | depends_on の依存先 fail → 後続ケース blocked | 委譲 |
| 06 | case-06_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 | 単独 |
| 07 | case-07_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録） | 委譲 |
| 08 | case-08_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-07 の対） | 委譲 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（スキルの「引き渡し」フォーマットへの参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 分岐の軸について

実行スキルはオーケストレータ `test` からの委譲起動が標準のため、本 evals の主軸は **実行手段（Playwright MCP・対象アプリ）の可否と結果 status の分岐**（pass / fail / blocked / skipped）である。
特に blocked と skipped の使い分け（skipped = 実行手段不在 / blocked = 前提不成立・タイムアウト等のテスト論理上のブロック。yaml-schema-results.md 6 章）を case-03〜05 で検証する。
起動形態の軸（委譲 / 単独）は case-06 のみで扱う。
