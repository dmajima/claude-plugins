# references/template/

ワークフロー成果物のテンプレート（SSOT）。`orchestrator-coding`（6 フェーズ）・`orchestrator-design`（4 フェーズ）が共用する。

## 原則

1. **フェーズ成果物は必ず対応テンプレートから作成する**（セクションの欠落を防ぐ。特に「品質ゲート判定」は全テンプレート末尾に必須）
2. **`{...}` プレースホルダは全置換**して使う（成果物に未置換のまま残さない）
3. テンプレートの構造変更は本ディレクトリでのみ行い、workflow.md 側に成果物の構造を重複記述しない

## ファイル一覧

| ファイル | フェーズ | 使用ワークフロー |
|---------|---------|----------------|
| [implementation-plan.md](implementation-plan.md) | Intake | coding / design 共通 |
| [impact-analysis.md](impact-analysis.md) | Analyze | coding / design 共通（design では「現状構造」セクションを必須記載） |
| [implementation-design.md](implementation-design.md) | Design | coding / design 共通 |
| [file-list.md](file-list.md) | Implement | coding のみ |
| [self-review-result.md](self-review-result.md) | Self-Review | coding のみ |
| [implementation-report.md](implementation-report.md) | Report | coding のみ |
| [design-report.md](design-report.md) | Report | design のみ |
