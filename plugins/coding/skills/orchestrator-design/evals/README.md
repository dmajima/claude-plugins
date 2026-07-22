# orchestrator-design evals

`orchestrator-design` の動作分岐ごとの期待挙動を定義するケース集。
言語検出・規約解決・未対応言語・モノレポ・SQL 方言判定などの分析系共通分岐は `orchestrator-coding` の evals（case-03 〜 case-06）と同一の SSOT に基づくため、本 evals では重複させない。本 evals は、設計ワークフロー固有の分岐（case-01〜03）に加え、共通の制御分岐を設計 WF（4 フェーズ・実装を伴わない）に特化させたケース（case-04 非対話 / case-05 品質ゲート遡行 / case-06 機密マスク）を扱う。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_design-only-request.md](case-01_design-only-request.md) | 設計のみの依頼（標準 4 フェーズ） |
| [case-02_implementation-request-redirect.md](case-02_implementation-request-redirect.md) | 実装込み依頼の受領 → orchestrator-coding への誘導 |
| [case-03_large-scale-architect-review.md](case-03_large-scale-architect-review.md) | 大規模・高リスク判定 → architect レビュー実施 |
| [case-04_non-interactive.md](case-04_non-interactive.md) | 非対話モード（--non-interactive）での設計フロー |
| [case-05_quality-gate-fail-backtrack.md](case-05_quality-gate-fail-backtrack.md) | 品質ゲート FAIL → 遡行制御（Phase 3 → Phase 2・分析起因） |
| [case-06_secret-masking.md](case-06_secret-masking.md) | 設計成果物への機密情報混入 → Phase 4 マスク経路 |

## 実行確認方法

各ケースの「入力」セクションのフレーズで Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。
