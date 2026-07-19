# test-run-integration evals

本ディレクトリは `test-run-integration` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_ita_flow_pass.md | IT-a 画面間遷移フロー pass（データ受け渡し突合を actual に記録） | 委譲 |
| 02 | case-02_itb_external_unreachable_stub_policy.md | IT-b 外部接続不可 → スタブポリシー判断（スタブ実行 / skipped の使い分け） | 委譲 |
| 03 | case-03_itb_fail_api_evidence.md | IT-b fail（マスク済み API レスポンスを証跡に含む defect 3 点セット） | 委譲 |
| 04 | case-04_ita_data_mismatch_fail.md | IT-a データ受け渡し不一致 fail（登録値・参照値の対比） | 委譲 |
| 05 | case-05_api_auth_credentials_guidance.md | API 補助確認に認証が必要 → credentials-manager 系スキル案内・フル値非出力 | 委譲 |
| 06 | case-06_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 | 単独 |
| 07 | case-07_mcp_unavailable_skipped.md | MCP ツール不可 → IT-a/IT-b 混在 scope 全件 skipped（二重防御） | 委譲 |
| 08 | case-08_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録） | 委譲 |
| 09 | case-09_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-08 の対） | 委譲 |
| 10 | case-10_playwright_test_run.md | automation: playwright-test × `npx playwright test` 実走 pass（IT-b をモックフィクスチャで差し替え再現可能に実走し全 pass を記録・executed_by: playwright-test・MCP 経路と併存） | 委譲 |
| 11 | case-11_playwright_test_skipped.md | automation: playwright-test だが Playwright/ランナー・fixtures.yaml/SUT テストコード不在 → skipped + reason（実走前提の欠如・MCP 未ロード skipped〔case-07〕とは別前提） | 委譲 |

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

実行スキルはオーケストレータ `test` からの委譲起動が標準のため、本 evals の主軸は **担当 2 レベル（IT-a / IT-b）の実行分岐**である。
IT-a はデータ受け渡し突合（pass / fail）、IT-b は外部接続可否とスタブポリシー判断（スタブ実行 / skipped）・API 補助確認（マスキング・認証情報の取り扱い）を検証する。
`automation: playwright-test`（`npx playwright test` 実走）経路は case-10（モックフィクスチャで IT-b を再現可能に実走する全 pass）/ case-11（実走前提不在の skipped）で扱い、MCP 経路（`automation: playwright`）と併存する。
起動形態の軸（委譲 / 単独）は case-06 のみで扱う。
