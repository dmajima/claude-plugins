# orchestrator-design evals

`orchestrator-design` の動作分岐ごとの期待挙動を定義するケース集。
言語検出・規約解決・未対応言語などの共通分岐は `orchestrator-coding` の evals（case-03 〜 case-07）と同一の SSOT に基づくため、本 evals では設計ワークフロー固有の分岐のみを扱う。

## ケース一覧

| ケース | 分岐トリガー |
|-------|-------------|
| [case-01_design-only-request.md](case-01_design-only-request.md) | 設計のみの依頼（標準 4 フェーズ） |
| [case-02_implementation-request-redirect.md](case-02_implementation-request-redirect.md) | 実装込み依頼の受領 → orchestrator-coding への誘導 |
| [case-03_large-scale-architect-review.md](case-03_large-scale-architect-review.md) | 大規模・高リスク判定 → architect レビュー実施 |
| [case-04_non-interactive.md](case-04_non-interactive.md) | 非対話モード（--non-interactive）での設計フロー |
