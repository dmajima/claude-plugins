# Case 10: APPROVE（指摘なしの正常完了パス）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`well-formed-skill` をレビュー" |
| 引数 | `well-formed-skill` |
| フラグ | なし |
| 既存状態 | スキルが存在し、機械チェック・専門家レビューともに合格状態 |

## 期待動作

### Phase 1〜4: 標準フロー

[case-01](case-01_skill_review.md) と同じ手順で `skill-review-team` を起動。機械チェックも並行実施。

### Phase 5: 結果統合

| 重大度 | 件数 |
|-------|-----|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0（または「Suggestion」のみ） |

すべての観点で問題なし、または軽微な改善提案のみ。

### Phase 6: 総合判定

Critical 0 + High 0 + Medium 0 → **APPROVE**。

| 判定ルール | 条件 |
|----------|------|
| **APPROVE** | Critical 0 + High 0 + Medium 0（Low / Suggestion のみ可） |
| CONDITIONAL_APPROVE | Critical 0 + High 1 件以上 または Medium 1 件以上 |
| REJECT | Critical 1 件以上 |

### Phase 7: 引き渡し

```text
総合判定: APPROVE（Critical / High / Medium 指摘なし）

軽微な提案（あれば）:
- {Suggestion 1}
- {Suggestion 2}

次のアクション:
- マーケットプレイス公開可能 → marketplace-publisher への接続を提案
- 公開不要なら作業完了
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | APPROVE 判定 + 軽微な Suggestion（あれば）+ 次のアクション案内 |
| 終了状態 | レビュー完了（合格） |

## 分岐の根拠

Critical / High / Medium 指摘 0 件 → APPROVE。

## 関連ケース

- `case-05_critical_reject.md`（Critical あり、REJECT）
- `case-06_conditional_approve.md`（High または Medium あり、CONDITIONAL_APPROVE）
