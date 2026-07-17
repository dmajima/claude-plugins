# case-29 自著限定の auto-resolve（他者起票スレッドは status 変更しない・P10）

自著 / 他者起票が混在する再レビューで、auto-resolve 既定でも自著スレッドのみ status を更新し、他者起票スレッドには reply / status 変更を行わないガードを検証するケース。全件自著の case-16 に対する混在分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（既存 active スレッド 2 件: 1 件は自著・解消済み / 1 件は他者起票・コード上は解消済みに見える。auto-resolve 引数なし＝既定） |
| モード | 非対話 |

## 分岐の根拠

references/skill-rules-matrix.md P10「自著限定 + auto-resolve 既定 / 他者起票スレッドへの reply / status 変更禁止」、comment-status-policy.md セクション 0.1（auto-resolve が既定）・セクション 0.2（自著スレッドのみ resolve・必須）、`${CLAUDE_SKILL_DIR}/references/author-identity.md`。全件自著の case-16 と異なり、自著 / 他者起票が混在し、他者起票側を触らないガードを検証する分岐。

## 期待動作

- 対象抽出（active・インライン）後、各スレッドの起票者を author-identity.md の一意識別子（uniqueName / login）で判定する（displayName は使わない。comment-status-policy.md セクション 0.2）
- 自著スレッド（解消済み）: Pattern A で解消確認 reply を投稿し status=fixed（Azure DevOps）/ resolved（GitHub）に更新する（auto-resolve 既定・P10）
- 他者起票スレッド（コード上は解消済みに見える）: reply も status 変更も行わず、「未解決のまま、手動確認推奨」としてレポートする（comment-status-policy.md セクション 0.2・禁止事項）
- 自著判定は大文字小文字を無視し、空文字ガードを行う（author-identity.md）
- 他者起票側を LLM 判定で resolve しない（P10 の中核ガード）
- サマリーの「6. 既存指摘の解消判定」に、自著=status 更新 / 他者起票=手動確認推奨 を区別して記載する
- 完了報告に自著 resolve 件数と他者起票スキップ件数を明記する

## 関連ケース

- case-16: 全件自著の Pattern A auto-resolve（自著のみで混在なしの分岐）
- case-03: 未解決コメント確認フロー（自著 / 他者起票の分類・対話モードの起点）
- case-17: Pattern C 未解消スレッドへの再観察 reply
