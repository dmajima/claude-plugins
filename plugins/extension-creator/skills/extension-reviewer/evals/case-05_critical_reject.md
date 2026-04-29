# Case 05: Critical 検出時の REJECT

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`broken-skill` をレビュー" |
| 引数 | `broken-skill` |
| フラグ | なし |
| 既存状態 | スキルに JSON valid 違反 + パスポータビリティ NG が含まれる |

## 期待動作

### Phase 1: 機械チェック

| 項目 | 結果 |
|-----|-----|
| JSON valid | NG（plugin.json パースエラー） |
| パスポータビリティ | NG（`C:\Users\...` 検出） |

### Phase 2: 並列エージェントレビュー

機械チェック結果と並行してエージェントレビュー実施。

### Phase 3: 総合判定

Critical 指摘あり → REJECT。

### Phase 4: 修正案内

```text
総合判定: REJECT

Critical 指摘（即時修正必須）:
- plugin.json: JSON パースエラー（{詳細}）
- SKILL.md: ローカル絶対パス検出（C:\Users\...）

修正後に再度レビューしてください。修正は以下のスキルで対応:
- plugin.json → plugin-creator
- SKILL.md のパス → skill-creator または手動編集後 extension-reviewer 再実行
```

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | REJECT 判定 + Critical 指摘詳細 + 修正先案内 |
| 終了状態 | レビュー完了（合格せず） |

## 分岐の根拠

Critical 指摘の存在 → REJECT。

## 関連ケース

- `case-01_skill_review.md`（標準・問題なし）
- `case-06_conditional_approve.md`（High はあるが Critical なしで CONDITIONAL_APPROVE）
