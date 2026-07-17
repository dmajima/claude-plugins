# case-03 未解決コメントがある PR の確認フロー

既存の未解決スレッドがある PR を確認するケース。再レビュー・解消判定（Pattern A / C 分岐）の起点として、対象スレッドの抽出と分類を行う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 の未解決コメントを確認して"（active な自著インラインスレッド 2 件 + 他者起票スレッド 1 件あり） |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 4/5「スレッド空配列時は Step 5 をスキップ」の逆条件。スレッドが存在するため Step 5（解消判定 → Pattern A / C 分岐）に進む。対象スレッドの抽出条件は re-review-flow.md セクション 4。

## 期待動作

- PR スレッド一覧を取得し、対象スレッドを抽出する
- 抽出条件: status が active かつ 自著（uniqueName / login が認証ユーザーと一致）かつ インライン（`threadContext.filePath != null`）をすべて満たすもののみ（re-review-flow.md セクション 4）
- PR 全体宛のサマリースレッド（`threadContext == null`）は対象外とする
- 自著判定に displayName を使用しない（comment-status-policy.md セクション 0.2）
- 他者起票スレッドは解消判定対象とせず「未解決のまま、手動確認推奨」としてレポートする（comment-status-policy.md セクション 0.2）
- 各対象スレッドを解消判定にかけ、Pattern A（解消）/ Pattern C（未解消）のいずれかに分類する（re-review-flow.md セクション 2）
- 統合サマリの「6. 既存指摘の解消判定」セクションに判定結果（パターン・操作）を記載する
- Step 8: 完了報告に解消確認した未解決コメント件数を出力する

## 関連ケース

- case-12: スレッド空配列時の早期スキップ（対になる分岐）
- case-16: Pattern A（解消確認 reply + status=fixed）
- case-17: Pattern C（再観察 reply・status=active 維持）
