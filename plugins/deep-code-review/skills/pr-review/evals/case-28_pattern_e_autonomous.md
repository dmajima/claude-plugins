# case-28 修正指示 + 修正コミット成立による Pattern E の自律発火（P28）

ユーザーの修正指示を受けて Claude がコードを修正・コミットした時点で、ack-fixed 引数の明示がなくても Pattern E（修正完了確認）を自律発火するケース。ack-fixed 引数で明示起動する case-14 に対する起動経路の対の分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "CR-002 の指摘を直して"（ユーザーの修正指示 → Claude がコードを修正し PR ブランチへコミット・push が成立。ack-fixed 引数の明示はなし） |
| モード | 対話 |

## 分岐の根拠

references/skill-rules-matrix.md P28「ユーザー修正指示 + Claude による修正コミット作成が成立した時点で ack-fixed 相当の処理を自律発火（reply 投稿 + status=fixed 化）」、comment-status-policy.md セクション 0.5.E（Pattern E・MANDATORY）、`${CLAUDE_SKILL_DIR}/references/scope-out-acknowledgment.md` セクション 8。ack-fixed 引数の明示起動（case-14）と異なり、修正コミット成立を検知して引数なしで自律発火する分岐。

## 期待動作

- ユーザーの修正指示に基づき Claude がコードを修正し、PR ブランチへ修正コミットを作成した事実を Pattern E のトリガー成立と判定する（P28・comment-status-policy.md セクション 0.5.E）
- ack-fixed 引数の明示がなくても、修正コミット成立時点で ack-fixed 相当処理を自律発火する（case-14 の明示起動との差分）
- 対象スレッドが自著かつ active であることを確認する（自著限定・他者起票は触らない。comment-status-policy.md セクション 0.5.E 安全方針）
- reply 本文に修正コミットへの明示リンク `[<sha7>](<commit-url>)` を必ず含める（P29・実証なき status 変更の禁止）
- reply 投稿後、status を fixed（Azure DevOps）/ resolve（GitHub）に更新する（Pattern A の解消判定は経ない）
- reply 投稿のみで status=active のまま放置しない（P30・完了前チェックリスト B-1.8）
- connector 呼び出し時に Bot 識別子マーカーを付与する（P12）
- 完了報告に処理した Finding ID・対応コミット・PR 最終状態を出力する（P19）

## 関連ケース

- case-14: 修正完了確認処理（ack-fixed 引数の明示起動・対になる起動経路）
- case-16: Pattern A 既定の auto-resolve（LLM 解消判定による fixed 化・使い分けの対比）
- case-13: スコープ外了承（Pattern D・別の即時 status 変更フロー）
