# case-17 Pattern C 未解消スレッドへの再観察 reply（status=active 維持）

再レビューで未解消（または自動判定不能）と判定された自著スレッドに対し、再観察 reply のみを投稿するケース。status は変更せず、同一箇所への新規スレッドも作成しない。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（既存自著スレッド 1 件・指摘箇所が未修正のまま） |
| モード | 非対話 |

## 分岐の根拠

re-review-flow.md セクション 1 / 2 の Pattern C「既存スレッドの指摘が解消されていない場合、status は active のまま維持 + 再観察 reply を投稿（新規スレッドは作らない）」。

## 期待動作

- 解消判定で未解消（または自動判定不能）と判定する
- 該当スレッドへ Pattern C の再観察 reply を投稿する（再レビュー実施日・対象 head SHA・判定を含む。re-review-flow.md セクション 3）
- connector 呼び出し時に `marker: [deep-code-review-plugin] unresolved; reply only` を指定し、署名に Bot 識別子を統合する（signatures.md 参照）
- スレッドの status は active のまま変更しない（fixed / resolved への PATCH を実行しない）
- 同一箇所に対する新規スレッドを作成しない（既存スレッドへ reply を積み上げる）
- auto-resolve の既定 / auto-resolve=false のいずれでも Pattern C の動作は同一（reply のみ・status 不変）
- サマリーの「6. 既存指摘の解消判定」セクションに Pattern C の操作（reply のみ）を記載する

## 関連ケース

- case-16: Pattern A（解消確認 reply + status=fixed、対になる分岐）
- case-14: 修正完了確認（ack-fixed。ユーザー指示で fixed 化する場合のフロー）
- case-15: auto-resolve=false 指定時の dry-run
