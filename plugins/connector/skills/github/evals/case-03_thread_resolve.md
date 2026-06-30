# Case 03: レビュースレッド resolve（パターン A）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/contoso/webapp/pull/42 のスレッド PRR_kwDOBxyz を resolve して" |
| 引数 | PR URL + スレッド ID |
| 既存状態 | `gh auth status` 認証済み。スレッド PRR_kwDOBxyz は isResolved=false |

## 期待動作

1. 認証確認
2. 書き込みと判定
3. `AskUserQuestion` で承認を得る
4. GraphQL `resolveReviewThread` mutation を実行
5. `thread.isResolved` が `true` になったことを確認して報告

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 承認質問 → スレッド resolve 完了報告 |
| 終了状態 | 成功 |

## 分岐の根拠

スレッド resolve は GraphQL mutation 経由の書き込み操作。REST API のコメント投稿とは異なる経路。
