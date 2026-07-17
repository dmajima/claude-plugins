# case-04 mode=quick 指定時の簡易レビュー

引数 mode=quick を指定して簡易モードでレビューするケース。code-review への委譲時に必須トリオ 3 観点のみが動員される。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして mode=quick" |
| モード | 対話 |

## 分岐の根拠

SKILL.md 実行モード判定「mode=standard（既定）/ quick（レビューモード）」。code-review 側は references/flow/mode-selection.md セクション 2.1「ユーザーが明示的にモード指定した場合はそのモードで即実行し AskUserQuestion はスキップ」+ references/flow/flow.md Step 3（簡易モードの動員表）。

## 期待動作

- mode=quick を解析し、モード確認の AskUserQuestion を呼び出さない
- Step 6: code-review への委譲 args に mode=quick を含める
- code-review は必須トリオ（code-review-implementation / code-review-testing / code-review-security）のみを並列起動する
- code-review-architecture / code-review-frontend は起動しない
- Agent Teams は採用しない（簡易モードはフォールバック条件。code-review references/flow/flow.md Step 3.5）
- 統合サマリの集計セクションに「レビューモード: 簡易」と明記する
- PR コメント投稿（インライン + サマリースレッド）は標準モードと同じく必須

## 関連ケース

- case-01: 標準モードの正常系
