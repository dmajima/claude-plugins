# Case 06: CONDITIONAL_APPROVE（High 指摘あり、Critical なし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` をレビュー" |
| 引数 | `code-formatter` |
| フラグ | なし |
| 既存状態 | スキル既存。SKILL.md は valid だが evals が分岐網羅性不足、description が短い等の High/Medium 指摘あり、Critical 指摘なし |

## 期待動作

### Phase 1〜3: 標準フロー

case-01 と同じ。エージェント並列起動 + 機械チェック。

### Phase 4: 結果統合

| 重大度 | 件数 |
|-------|-----|
| Critical | 0 |
| High | 2（evals の網羅性不足、description が短すぎる） |
| Medium | 3 |
| Low | 1 |

### Phase 5: 総合判定

Critical 0 + High 1 件以上 → **CONDITIONAL_APPROVE**。

| 判定ルール | 条件 |
|----------|------|
| APPROVE | Critical 0 + High 0（Medium / Low のみ） |
| CONDITIONAL_APPROVE | Critical 0 + High 1 件以上（修正後再レビュー推奨） |
| REJECT | Critical 1 件以上 |

### Phase 6: 引き渡し

```text
総合判定: CONDITIONAL_APPROVE（High 指摘 2 件、修正後再レビュー推奨）

High 指摘:
- {問題 1}（{担当エージェント}）
- {問題 2}（{担当エージェント}）

次のアクション:
- High 指摘の修正は `skill-creator` で対応してください
- 修正後に `extension-reviewer` を再実行してください
- マーケットプレイス公開は High 指摘解消後を推奨します
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | CONDITIONAL_APPROVE 判定 + High 指摘詳細 + 次のアクション案内 |
| 終了状態 | レビュー完了（条件付き合格） |

## 分岐の根拠

Critical 0 件 + High 1 件以上 である。

## 関連ケース

- `case-01_skill_review.md`（標準スキルレビュー）
- `case-05_critical_reject.md`（Critical あり、REJECT）
