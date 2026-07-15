# Case 10: Phase 5 → Phase 4 遡行（実装バグ起因・遡行テーブル主経路）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「商品一覧 API にページネーションを追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | TypeScript（Express）プロジェクト。Phase 5 の test-engineer が「境界値で最終ページの 1 件が欠落する off-by-one（High）」を指摘する状況。設計（offset / limit 方式）自体は妥当 |

## 期待動作

### Phase 5: Self-Review（FAIL 検出）
- `coding:impl-reviewer` + `coding:test-engineer` を並列起動
- test-engineer の High 指摘により品質ゲート判定 = FAIL
- 指摘原因の切り分け: 設計方針（offset / limit によるページネーション）は正しく、**実装のオフセット計算のバグ**（総件数の端数処理で最後の 1 件を取りこぼす）が原因と判断 → **実装起因**

### 遡行処理（Phase 4 へ遡行 = 遡行テーブルの主経路）
- 設計は変更不要のため Phase 3 へは戻さず、**Phase 4 へ遡行**（workflow.md 節 0.3 の「Phase 5 で Critical / High 指摘 → Phase 4」の主経路）
- Phase 4: オフセット計算を修正し、境界値（最終ページ・総件数がページサイズの倍数/非倍数）のテストを追加。file-list.md を更新
- Phase 5: **指摘該当箇所（ページネーションロジックとそのテスト）のみ再レビュー**。全件再レビューはしない
- self-review-result.md の「遡行記録」に回数・理由（実装バグ起因）・修正内容を記録 → 再レビューで Critical / High = 0 件となり PASS

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 遡行先 | Phase 4（設計は保持。implementation-design.md は変更しない） |
| 生成ファイル | file-list.md（修正反映）+ self-review-result.md（遡行記録: 実装起因、該当箇所のみ再レビュー） |
| 終了状態 | 成功（遡行後 PASS） |

## 分岐の根拠

このケースが分岐するトリガーは 品質ゲート判定 = FAIL かつ指摘原因 = 実装起因（設計は正しい）である。workflow.md 節 0.3 遡行規定の「Phase 5 で Critical / High 指摘 → Phase 4（設計起因なら Phase 3）」のうち、**主経路である Phase 4 遡行**を検証する。

## 関連ケース

- `case-08_quality-gate-fail-backtrack.md`（**設計起因**のため Phase 3 へ遡行する分岐。本ケースは実装起因のため Phase 4 に留まる点が対照的）
- `case-09_architect-design-review.md`（設計指摘と実装指摘が競合し裁定を経て遡行するケース）
- `case-11_backtrack-early-phases.md`（前段フェーズの遡行共通挙動）
