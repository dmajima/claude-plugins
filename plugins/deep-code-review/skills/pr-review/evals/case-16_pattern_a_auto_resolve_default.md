# case-16 Pattern A 既定の auto-resolve（解消確認 reply + status=fixed）

auto-resolve 既定（`${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` セクション 0.1）で再レビューを実行し、既存自著スレッドのうち解消済みの 1 件に対して解消確認 reply の投稿と status=fixed 更新まで実施するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（既存自著スレッド 2 件・うち 1 件は解消済み・auto-resolve 引数なし） |
| モード | 非対話 |

## 分岐の根拠

comment-status-policy.md セクション 0.1「ユーザーが明示的に auto-resolve=false を指定しない限り、解消確認できたスレッドのステータス更新まで実施する」+ re-review-flow.md セクション 2 の Pattern A（解消・自動）。

## 期待動作

- 対象抽出条件（active・自著・インライン）を満たすスレッドのみ解消判定にかける（re-review-flow.md セクション 4）
- 解消確認できたスレッドへ Pattern A の解消確認 reply を投稿する（再レビュー実施日・対象 head SHA・判定を含む。re-review-flow.md セクション 3）
- connector 呼び出し時に `marker: [deep-code-review-plugin] auto-resolve (default)` を指定し、署名に Bot 識別子を統合する（signatures.md / comment-status-policy.md セクション 0.4）
- 同スレッドの status を fixed（Azure DevOps）/ resolved（GitHub）に更新する
- 未解消の残り 1 件は Pattern C として reply のみ投稿し status=active を維持する
- 新しいサマリーは既存サマリースレッドへの reply ではなく新規スレッドとして投稿し、旧自著サマリーは status=closed に更新する（re-review-flow.md セクション 4）
- サマリー本文は template/review-summary.md（code-review スキル references/output/template/）準拠で、各 H2 セクションを `<details><summary>` 折り畳み + 内部 HTML 記法（`<h3>` / `<table>` / `<code>` 等）で出力する（タイトル行・ヘッダブロックは折り畳み対象外）
- サマリーの「6. 既存指摘の解消判定」セクションに Pattern A の操作（status=fixed + reply）を記載する

## 関連ケース

- case-15: auto-resolve=false 指定時の dry-run（対になる分岐）
- case-17: Pattern C（未解消スレッド）
- case-03: 未解決コメント確認（起点フロー）
