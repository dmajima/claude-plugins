# orchestrator-coding スキル evals

`orchestrator-coding` スキルの動作分岐ごとの期待挙動を定義するケース集。
各ケースは仕様書として機能する（対話型ワークフローのため自動実行フロントマターは付与しない）。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_standard-full-workflow.md](case-01_standard-full-workflow.md) | 標準モード・全 6 フェーズ実施 |
| [case-02_quick-mode.md](case-02_quick-mode.md) | 小規模修正 → クイックモード判定 |
| [case-03_project-conventions-override.md](case-03_project-conventions-override.md) | プロジェクト独自規約がデファクトより優先 |
| [case-04_unsupported-language.md](case-04_unsupported-language.md) | 言語スキル未収録言語の検出 |
| [case-05_monorepo-multi-language.md](case-05_monorepo-multi-language.md) | 複数言語モノレポでの言語スキル併用 |
| [case-06_sql-dialect-unknown.md](case-06_sql-dialect-unknown.md) | SQL 方言判定不能時の確認 |
| [case-07_non-interactive.md](case-07_non-interactive.md) | 非対話モード（--non-interactive） |
| [case-08_quality-gate-fail-backtrack.md](case-08_quality-gate-fail-backtrack.md) | 品質ゲート FAIL → 遡行制御（Phase 5 → Phase 3 設計起因） |
| [case-09_architect-design-review.md](case-09_architect-design-review.md) | 大規模判定 → architect 設計レビュー → Phase 5 設計 × 実装指摘の競合裁定 |
| [case-10_backtrack-phase5-to-phase4.md](case-10_backtrack-phase5-to-phase4.md) | 実装バグ起因の High → Phase 4 遡行（遡行テーブル主経路） |
| [case-11_backtrack-early-phases.md](case-11_backtrack-early-phases.md) | 前段フェーズの遡行共通挙動（Phase 2 → Phase 1 主／Phase 3→2・4→3・6→該当） |
| [case-12_secret-masking.md](case-12_secret-masking.md) | 成果物への機密情報混入 → Phase 6 マスク経路 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。
