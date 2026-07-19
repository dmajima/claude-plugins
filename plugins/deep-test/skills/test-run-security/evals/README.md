# test-run-security evals

本ディレクトリは `test-run-security` 実行スキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / `references/security-execution.md` / `${CLAUDE_PLUGIN_ROOT}/references/`）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | 観点 |
|------|-----------|------------|------|
| 01 | case-01_header_missing_fail.md | セキュリティヘッダ欠如検出 fail（owasp_category 記録） | セキュリティヘッダ |
| 02 | case-02_unauth_access_control_pass.md | 未認証アクセス制御が有効で pass | 認証 |
| 03 | case-03_xss_reflection_harmless.md | XSS 反射確認（無害ペイロードのみ・破壊行為なし） | 入力検証 |
| 04 | case-04_sensitive_masking.md | 機微情報マスキング動作（保管時・返却時にマスク） | セッション管理 / 情報露出 |
| 05 | case-05_mcp_unavailable_skipped.md | MCP 未ロード（ブラウザ依存は skipped・curl 完結ヘッダ検査は実施） | セキュリティヘッダ / 認証 |
| 06 | case-06_out_of_scope_operation_declined.md | 破壊的操作・対象外領域の拒否（実施せず reason 記録・「問題なし」としない） | 破壊的操作 / 対象外 |
| 07 | case-07_standalone_missing_inputs.md | 単独起動で必須入力欠落 → 実行せずオーケストレータ経由を案内 | 単独起動 |
| 08 | case-08_timeout_blocked.md | ケースタイムアウト超過 → blocked + reason（次ケースへ継続） | タイムアウト |
| 09 | case-09_manual_assist.md | automation: manual-assist × 対話（人手確認・executed_by: human-assisted で記録・機微情報マスキング） | 人手確認 |
| 10 | case-10_manual_assist_non_interactive.md | automation: manual-assist × 非対話（skipped + reason で返却。case-09 の対） | 人手確認 |
| 11 | case-11_auth_fixture_storagestate_switch.md | automation: playwright-test × `npx playwright test` 実走 pass（認証フィクスチャ storageState で認証済み/未認証を切替え到達可否の挙動差を非破壊検証し pass 記録・executed_by: playwright-test・MCP 経路と併存） | 認証 / セッション管理 |
| 12 | case-12_playwright_test_skipped.md | automation: playwright-test だが Playwright/ランナー・fixtures.yaml（認証フィクスチャ）/SUT テストコード不在 → skipped + reason（実走前提の欠如・MCP 未ロード skipped〔case-05〕とは別前提） | 認証 / セッション管理 |

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

- 本スキルの実行結果は中間データとして返却するのみで、`test-results.yaml` への書き込みはオーケストレータ `test` が行う
- 実行は承認済みケースの範囲・非破壊操作に限定し、破壊的攻撃・対象外領域（ペネトレーションテスト・SCA・SAST）は行わない
- evals は「返却する中間結果 JSON の内容」と「操作境界・マスキングの遵守」を検証対象とする
- `automation: playwright-test`（`npx playwright test` 実走）経路は case-11（認証フィクスチャ storageState 切替の全 pass）/ case-12（実走前提不在の skipped）で扱い、MCP・`curl` 経路と併存する（0 章の非破壊境界は不変）
