# case-24 worktree の NG 判定時維持と SKIPPED 例外（P4）

レビュー結果が NG（Needs Work）の場合に worktree を維持する分岐と、worktree 作成が SKIPPED になる例外条件を検証する。全 OK 判定・削除を暗黙前提にしないための否定パスケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 想定シナリオ | (A) レビュー結果が NG・再レビュー要（Critical/High あり）で worktree を維持 / (B) worktree 作成が失敗（clone 権限なし・ディスク不足・PR ブランチ fetch 不可）で SKIPPED |
| モード | 対話 |

## 分岐の根拠

references/skill-rules-matrix.md P4（worktree 分離環境: Step 5.5 で PR ブランチを worktree にチェックアウト、Step 7.5 でレビュー判定に応じて worktree を処理（OK: 削除、NG: 維持））、`${CLAUDE_SKILL_DIR}/references/local-checkout-review.md`、SKILL.md「Step 7.5: 完了前チェックリスト」。

## 期待動作

- シナリオ (A): レビュー結果が NG（Needs Work / Needs Attention）の場合、Step 7.5 で worktree を **削除せず維持** する（P4「NG: 維持」）。維持した worktree のパスを完了報告（Step 8）と統合サマリの「9. レビュー実施環境」に記載する（ユーザーが修正作業に利用できるようにするため）
- シナリオ (B): worktree 作成（Step 5.5）が失敗した場合、SKIPPED として記録し、その理由（clone 権限なし・fetch 不可等）を統合サマリの「9. レビュー実施環境」の worktree 欄に明示する。worktree なしでレビューを継続するか、続行不能ならユーザーに案内する
- OK 判定時のみ worktree を削除する（P4「OK: 削除」）。全ケースで削除を暗黙前提にしない
- メインリポジトリの作業状態は worktree 分離により一切変更しない（local-checkout-review.md）

## 関連ケース

- case-06: TFS NTLM の PR レビュー（worktree 作成の正常系）
- case-10: 投稿順序（OK 判定・worktree 削除の正常系）
