# code-review evals

本ディレクトリは `code-review` オーケストレータースキルの **AI の動作分岐検証ケース集**。
1 ケース 1 ファイルで、スキルの規範（SKILL.md / references/）に基づく分岐ごとに期待動作を定義する。

## ケース一覧

| case | ファイル名 | 検証する分岐 | モード |
|------|-----------|------------|--------|
| 01 | case-01_standard_mode_fresh.md | 標準モード・初回レビュー（state.yaml なし・サブエージェント方式） | 対話 |
| 02 | case-02_quick_mode.md | 簡易モード（必須トリオ 3 観点のみ動員） | 対話 |
| 03 | case-03_re_review_with_state.md | 前回 state.yaml ありの再レビュー（remaining_issues 引き継ぎ） | 対話 |
| 04 | case-04_trigger_natural_language.md | 自然言語フレーズでのトリガー起動（対話・既定スコープ） | 対話 |
| 05 | case-05_non_interactive_default.md | 非対話モードの既定動作（AskUserQuestion 不発火・フォールバック通知） | 非対話 |
| 06 | case-06_multilang_detection.md | 多言語モノレポの言語・FW 検出と観点プロファイル委譲（C23 / O10） | 対話 |
| 07 | case-07_confidence_cutoff_unsupported_lang.md | 信頼度足切り（C24）と未対応言語の明示 | 対話 |
| 08 | case-08_merge_judgment.md | マージ可否判断フレーズでの起動と Verdict 明示 | 対話 |
| 09 | case-09_verdict_override.md | Verdict オーバーライド（test-runner RED / エージェント強制評価・C6） | 対話 |
| 10 | case-10_agent_teams_adopted.md | Agent Teams 採用（大規模・クリティカル差分・ユーザー承認パス・C4） | 対話 |
| 11 | case-11_agent_teams_rejected_fallback.md | Agent Teams 却下 → サブエージェント方式フォールバック（C4） | 対話 |
| 12 | case-12_pr_review_internal_data_return.md | pr-review 委譲時の内部データ返却（対話文なし・C22） | 委譲 |
| 13 | case-13_verdict_attention_ready.md | Verdict 判定境界（Needs Attention / Ready to Merge・C6） | 対話 |
| 14 | case-14_profile_anchor_reconcile.md | プロファイルアンカー照合による過小評価の是正（Low → Issues 再配置・C25） | 対話 |
| 15 | case-15_finding_id_naming_collision.md | Finding ID 命名衝突時の REV-NNN プレフィクス切替（output-format.md セクション 1.5） | 対話 |
| 16 | case-16_u16_regression_integration.md | 削除側防御コードの回帰（U16）を Issues に計上する統合分岐 | 対話 |
| 17 | case-17_agent_teams_data_quality.md | Agent Teams パターン4 選定（DB 主体・data-quality-extended・C4） | 対話 |
| 18 | case-18_agent_teams_system_design.md | Agent Teams パターン3 選定（大規模設計変更・技術選定主体・system-design・C4） | 対話 |
| 19 | case-19_agent_teams_frontend_quality.md | Agent Teams パターン5 選定（大規模 UI・Vue.js/Liquid 再構築主体・frontend-quality-extended・C4） | 対話 |
| 20 | case-20_c8_scope_out_section_separation.md | C8 スコープ外指摘の専用セクション分離（判断理由付き格納・C13/C14 連番整合の正常系） | 対話 |
| 21 | case-21_c2_compare_branch_fallback.md | C2 比較ブランチ自動判定のフォールバック実演（origin/develop 不在 → main → master） | 対話 |
| 22 | case-22_thread_id_transcription_success.md | C19 PR Thread ID の state.yaml 転記成功（finding-thread-map.json 既存 → Finding ID 照合で転記・case-12 の null 分岐と対） | 委譲 |
| 23 | case-23_u14_code_reference_approval_seek.md | U14/C20 コード信頼性原則の承認シークフロー（明文化規約なし → AskUserQuestion 2択・承認記録 / 非承認継続の 3 分岐・case-03 の再利用と対） | 対話 |
| 24 | case-24_conventions_priority_machine_over_default.md | 規約優先順位解決（.editorconfig〈優先度2機械設定〉> 言語デファクト〈優先度5〉・衝突抑止・conventions-resolution 2.2） | 標準 |
| 25 | case-25_conventions_missing_item_sibling_debt.md | 欠落系指摘の兄弟コード確認による既存負債判定（投機的 High 抑止 → スコープ外寄せ・conventions-resolution 2.5） | 標準 |
| 26 | case-26_agent_teams_quality_assurance_adopted.md | Agent Teams パターン1 採用（標準的大規模品質・quality-assurance・承認 → Step 4-T 継続・C4。case-11 却下と対） | 対話 |
| 27 | case-27_inputs_hearing_ticket_conditional.md | inputs ヒアリングフロー（チケット未検出時の外部チケット選択肢除外・4択 vs 3択・C17） | 対話 |
| 28 | case-28_duplicate_merge_heaviest_severity.md | 重複指摘の統合（同一行の複数エージェント指摘を最重要度採用・連名・最大信頼度・「他に N 件」・C5/U11/U15） | 標準 |
| 29 | case-29_compare_branch_origin_head_fallback.md | 比較ブランチ自動判定の最終フォールバック（develop/main/master 全不在 → origin/HEAD・C2。case-21 の中間段と対） | 標準 |

## ケースファイルの構成

各ケースファイルは以下のセクションで構成する。

| セクション | 内容 |
|-----------|------|
| 入力 | 起動フレーズ / 対話・非対話モード |
| 分岐の根拠 | SKILL.md / references のどの規範に基づく分岐か（ファイル名・セクションを明記） |
| 期待動作 | 検証可能な期待動作の箇条書き |
| 関連ケース | 対になる分岐・前提となるケースへの参照 |
