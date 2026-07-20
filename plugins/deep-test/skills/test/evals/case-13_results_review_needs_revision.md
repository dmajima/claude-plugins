# case-13 結果レビュー NEEDS REVISION → ids 再実行による遡行

Phase 6 の結果レビューで修正を要する指摘（再現手順不備・severity 不当）を受けた場合に、実績を書き換えず ids モードの追加 run で遡行すること・上限 3 回を守ることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 状況 | フルフローの Phase 6。test-review（結果文脈）の返却に、TC-FUNC-002 の再現手順不備（環境情報欠落で第三者再現不能）と TC-SYS-001 の severity 過大評価（補正案 high → medium・根拠付き）の指摘、および分析・所見レベルの指摘 1 件（実績の変更不要）が含まれる |
| 前提 | run は finish-run 済み（status=completed）。対話モード |

## 分岐の根拠

SKILL.md「実行フロー」Phase 6（NEEDS REVISION の遡行は flow.md 4 章・上限 3 回）と「重要な制約」（select を経ない再テスト対象の確定禁止・test-results.yaml の直接編集禁止）、references/flow.md 1 章（Phase 6 → Phase 5: NEEDS REVISION〔ids 再実行。ループ 3 回まで〕）・4.2（結果文脈の遡行: 結果は append-only のため「再実行による上書きではなく追加 run」で行う / 3 点セット品質の不備 → 該当ケースを ids モードで再実行し充足した defect で再記録 / severity 疑義 → 実績の書き換えはせず ids 再実行で再記録 / 分析・所見レベルの指摘 → test-report へ引き渡し・遡行しない / 上限 3 回・超過時は 4.1 と同一）、プラグイン共通 references/retest-policy.md 1 章（ids は新規 run）・7 章（append + latest 更新。既存エントリの上書き・書き換え・削除は禁止）、references/review-criteria.md 4 章（結果文脈は判定ゲートなし。severity 補正は提案のみで実績反映しない）。

## 期待動作

- 指摘を受けても test-results.yaml の既存 runs / results エントリを書き換えない（Edit / Write の直接編集はもちろん、results_manager.py による上書き・削除も行わない。append-only）
- severity 補正案を「記録の修正」で反映しない（defect-analyst の補正案を採用する場合も、該当ケースの ids 再実行による再記録で行う。flow.md 4.2）
- 遡行対象は指摘対象の 2 ケースのみとし、`results_manager.py select --mode ids --ids "TC-FUNC-002,TC-SYS-001"` で機械的に確定する（LLM の判断で対象を追加・除外しない）
- `start-run --mode ids` で**新規 run_id** を採番し、該当実行スキルへ委譲 → 充足した defect（環境情報を含む完全な再現手順・妥当な severity）で record → finish-run する
- 分析・所見レベルの指摘は遡行対象にせず、test-report への引き渡し事項（報告書の NG 詳細・所見への反映）として保持する
- 再実行後に Phase 6（結果レビュー）を再度実施し、指摘が解消していれば Phase 7 へ進む
- 遡行ループは**上限 3 回**。超過時は対話 = AskUserQuestion（続行 / 中断 / 指摘を許容して進行）、非対話 = エラー中断（flow.md 4.1 と同一の扱い）
- 「指摘を許容して進行」が選択された場合、未解消の指摘を引き渡しと報告書の未確認事項に転記する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（ids 再実行の新規 run を results_manager.py の start-run → record → finish-run で append。既存 runs / results の書き換え・削除なし。latest は再記録で更新）・遡行解消後に報告書を生成 |
| 標準出力（要約） | 指摘 2 件の遡行方針（ids 再実行・新規 run_id）と所見レベル指摘の test-report への引き継ぎを説明。遡行完了後は SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | 追加 run（ids）の status=completed → 結果レビュー再実施 → Phase 7 完了。上限 3 回超過時は対話 = ユーザー判断 / 非対話 = エラー中断 |

## 関連ケース

- case-04: 設計文脈の NEEDS REVISION 遡行（design 差し戻し側。上限 3 回の規則は共通）
- case-10: ids モードの対象判定（本ケースの遡行は ids 再実行を利用する）
- case-06: fail 記録時の一次バリデーション（記録前の欠落検出。本ケースは記録後のレビュー指摘による遡行）
