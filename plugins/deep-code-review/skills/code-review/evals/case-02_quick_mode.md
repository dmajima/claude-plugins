# case-02 簡易モード（必須トリオ 3 観点）

ユーザーが簡易モードを明示してレビューするケース。観点別スキルは必須トリオのみ動員し、動的省略は行わない。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチを軽くレビューして" |
| モード | 対話（モード明示のため AskUserQuestion はスキップ） |

## 分岐の根拠

references/flow/mode-selection.md セクション 2.1「簡易レビュー / 軽くレビュー / クイックレビュー 等の表現はそのモードで即実行し AskUserQuestion をスキップ」、references/flow/flow.md Step 3（簡易モード: 必須トリオ必須・動的省略なし）、flow.md Step 3.5 フォールバック条件「簡易モード（mode=quick）」。

## 期待動作

- ユーザー表現「軽くレビュー」から簡易モードを特定し、モード確認の AskUserQuestion を呼び出さない
- code-review-implementation / code-review-testing / code-review-security の 3 観点のみを並列起動する（委譲 args に mode=quick を含める）
- code-review-architecture / code-review-frontend は起動しない
- 必須トリオの動的省略は行わない（3 観点を常に動員する）
- 各観点別スキル内部の補助エージェント（linter / perf / runner / dep）は通常通り動作する（mode-selection.md セクション 1。動的検証は権限がなければ SKIPPED）
- Agent Teams は採用しない（簡易モードはフォールバック条件）
- 統合サマリの集計セクションに「レビューモード: 簡易」と明記する
- Step 8.5: state.yaml の mode フィールドに簡易モードを記録する

## 関連ケース

- case-01: 標準モード（5 観点）
