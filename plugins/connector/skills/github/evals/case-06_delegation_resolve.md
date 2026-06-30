# Case 06: 他プラグイン委譲によるスレッド resolve（パターン B）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:github", args: "PR URL: https://github.com/contoso/webapp/pull/42 のスレッド PRR_kwDOBxyz を resolve。承認済み。marker: [orchestrator-fix] fix-reply")` |
| 既存状態 | 呼び出し元は coding の orchestrator-fix。gh CLI 認証済み。スレッド PRR_kwDOBxyz は isResolved=false |

## 期待動作

1. パターン B と判別（「承認済み」を含む）
2. 認証確認（gh auth status）
3. 承認スキップ（「承認済み」明示）
4. GraphQL `resolveReviewThread` mutation を実行
5. 署名は本操作では対象外（resolve はステータス変更であり本文投稿ではない）
6. 結果を呼び出し元に返す（isResolved: true）

## 分岐の根拠

パターン B でのスレッド resolve。orchestrator-fix case-10/11 が依存する操作の受け側ケース。
