# test-setup evals

本ディレクトリは `test-setup` フェーズスキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/ / プラグイン共通 references）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 起動形態 |
|------|-----------|------------|---------|
| 01 | case-01_mcp_unregistered_register_handoff.md | MCP 未登録 → 規約コマンドで登録 + 再起動ハンドオフを出力して停止 | 単独 |
| 02 | case-02_mcp_registered_loaded_ready.md | MCP 登録済み + ロード済み → 実利用可と判定し READY を返却 | 委譲 |
| 03 | case-03_mcp_registered_not_loaded_restart.md | MCP 登録済み + 未ロード → 再登録せず再起動案内（RESTART_REQUIRED） | 委譲 |
| 04 | case-04_runner_detection_report.md | テストランナー検出結果の返却形式（根拠ファイル・実行コマンド例の併記） | 単独 |
| 05 | case-05_unit_only_scope_skip_mcp.md | `levels=unit` のみ → Playwright MCP チェックを対象外（not-checked）として省略 | 委譲 |
| 06 | case-06_multiple_playwright_registrations.md | playwright 系登録が複数 × 対話 → AskUserQuestion で採用登録を選択 | 単独 |
| 07 | case-07_partial_result.md | venv 構築失敗 + MCP 利用可の混在 → 総合判定 PARTIAL・影響範囲明示 | 委譲 |
| 08 | case-08_registration_failure_and_runner_none.md | MCP 新規登録失敗（リトライ 1 回まで → failed）+ ランナー none の複合 → PARTIAL・影響範囲明示 | 委譲 |
| 09 | case-09_multiple_playwright_registrations_non_interactive.md | playwright 系登録が複数 × 非対話 → `playwright` 優先採用（無ければ先頭・不採用は列挙） | 委譲 |
| 10 | case-10_mcp_list_error_not_checked.md | `claude mcp list` 自体がエラー終了 → 登録状態 not-checked として続行（runner / venv は継続・PARTIAL） | 委譲 |
| 11 | case-11_non_interactive_unregistered_not_registered.md | 非対話 + Playwright 必要レベルあり + 未登録 → 登録せず not-registered（永続的副作用を作らない・PARTIAL・該当レベル skipped 見込み） | 委譲 |
| 12 | case-12_interactive_registration_declined.md | 対話 + Playwright 必要レベルあり + 未登録 → AskUserQuestion で登録確認 → 否認で not-registered（PARTIAL。case-11 の対話版） | 委譲 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 委譲 args または起動フレーズ / 起動形態（委譲・単独）・前提状態 |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・章を明記） |
| 期待動作 | 検証可能な期待動作の箇条書き（実行するコマンド・生成物・判定・返却内容） |
| 期待出力 | 生成ファイル / 標準出力（要約）/ 終了状態の表（環境検証レポート・総合判定への参照でよい） |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |

## 起動形態の軸について

本スキルの evals は「委譲（オーケストレータ `test` 経由）」と「単独（ユーザー直接起動）」の 2 起動形態を扱う。
いずれの形態でも検出・登録・判定のロジックは同一であり、差が出るのは再起動ハンドオフの提示主体（委譲時はオーケストレータが提示、単独時は本スキルが直接提示）のみである。
