# case-04 設計レビュー NEEDS REVISION → 修正ループ（2 回目 PASS）

設計レビューゲートの不通過時に、実行フェーズをブロックしたまま design 修正ループを回し、上限内（2 回目 PASS）で収束することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」 |
| 前提 | フルフロー・対話モード。test-review（設計文脈）が 1 回目 NEEDS REVISION（境界値ケース不足・requirement 対応漏れの指摘）、2 回目 PASS を返す |

## 分岐の根拠

SKILL.md「実行フロー」Phase 3（NEEDS REVISION → 指摘リストを添えて test-design へ差し戻す修正ループ・上限 3 回）、references/flow.md 4.1（ループ回数の数え方 =「test-design への差し戻し」を 1 回と数える / findings は要約せず引き渡す）、プラグイン共通 references/execution-policy.md 1.1（設計レビューゲート定義）、references/yaml-schema-cases.md 3 章（revision +1 で draft 戻し）。

## 期待動作

- 1 回目 NEEDS REVISION を受領したら、run 側フェーズ（Phase 4 以降）へ進まない（実行フェーズのブロック）
- test-review の `findings`（指摘内容・根拠・対象ケース ID・信頼度）を**要約で情報を落とさず**そのまま test-design へ引き渡して修正を委譲する
- 修正後のケースは revision +1 で draft に戻ることを前提に、再度 test-review（設計文脈）を起動する
- ループ回数を「test-design への差し戻し」の回数（この時点で 1 回）として数え、上限 3 回の管理を維持する
- 2 回目 PASS で approved 化を test-design へ委譲し、Phase 4 へ進む
- ループ中に test-cases.yaml をオーケストレータ自身が編集して指摘を解消しない（修正は test-design の責務）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-cases.yaml は test-design の修正で revision +1（draft 戻し）→ PASS 後に approved（オーケストレータ自身は編集しない）。PASS 後の後続フェーズで test-results.yaml（results_manager.py 経由。Edit / Write の直接編集なし）と報告書を生成 |
| 標準出力（要約） | 差し戻し中は指摘リストの引き渡しと修正ループの経過報告。PASS 後に SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | 差し戻し中は Phase 4 以降をブロック。2 回目 PASS で completed まで到達 |

## 関連ケース

- case-01: 1 回で PASS する正常系
- case-16: 修正ループが上限 3 回を超過した場合の分岐（対話 3 択）
- case-05: 非対話時のループ超過はエラー中断（ユーザー判断を挟まない）
- case-02: 承認済みケースゲート経由の設計レビュー（draft 混入時）も同じ PASS / NEEDS REVISION 判定を用いる
