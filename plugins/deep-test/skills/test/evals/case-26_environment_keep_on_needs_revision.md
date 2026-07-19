<!-- TEST-ORCH-EVAL-R2-26-SENTINEL-v1 -->
# case-26 結果レビュー NEEDS REVISION 時の環境維持（down せず ids 再実行に備える・再実行 PASS 後に down）

Phase 6 の結果レビューが NEEDS REVISION の場合に、environment を **down せず維持**して ids 再実行に備え、再実行後の PASS 判定時に down してから Phase 7 へ進むことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 状況 | 環境統合フルフロー（case-25 と同構成）の Phase 6。test-review（結果文脈）が NEEDS REVISION（TC-FUNC-002 の再現手順不備）を返す。environment は `status.state: healthy`（up 済み・down 未実施） |
| 前提 | run は finish-run 済み（status=completed）。対話モード |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」5（down は Phase 6 判定後 = PASS → down・NEEDS REVISION → ids 再実行に備え維持）・SKILL.md「検証」（維持する場合〔NEEDS REVISION の ids 再実行待ち等〕は理由を明示している）・SKILL.md「引き渡し」（environment up 後の中断: 残存確認と手動 down 手順を必ず案内）、references/flow.md Phase 6 節（判定後の environment down: PASS → down して Phase 7 へ・NEEDS REVISION → ids 再実行〔4.2〕に備えて**維持**する。down は再実行完了後の PASS 判定時に実施）・4.2（結果文脈の遡行: ids 再実行による追加 run・上限 3 回）・5.2（中断時に environment が up のまま残る場合は手動 down を案内）。

## 期待動作

- Phase 6 で NEEDS REVISION を受領した時点では `action=down` を**委譲しない**（環境を維持し、維持理由〔ids 再実行待ち〕を明示する）
- 遡行は flow.md 4.2 に従い `select --mode ids` → `start-run`（新規 run_id）→ 該当実行スキルへ委譲 → record → finish-run で行う（append-only。既存実績の書き換えなし）
- ids 再実行では維持中の環境を**再利用**する（再 provision・再 up を既定では行わない。健全性に疑義があれば `action=status` で ps + health を再確認してよい）
- 再実行後の結果レビューが PASS になった時点で `action=down run-id={最新 run_id}` を委譲し、down 完了後に Phase 7 へ進む
- 遡行ループ上限（3 回）超過などでユーザーが中断を選んだ場合は、環境が up のまま残る旨・残存確認（`docker compose -p {slug}-test ps`）と手動 down（`action=down`）の手順を中断案内に必ず含める
- 完了報告前の検証で `{slug}-test` の残存コンテナがない（down 済み）ことを確認する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（ids 再実行の追加 run を results_manager.py 経由で append）・environment.yaml の status は維持中 up / healthy のまま → PASS 後の down で down へ更新（更新は test-environment が実施） |
| 標準出力（要約） | NEEDS REVISION 時: 環境維持の旨と維持理由・遡行方針。PASS 後: down 完了を含む SKILL.md「引き渡し」の正常フォーマット |
| 終了状態 | 遡行完了 → PASS → down → Phase 7 完了。中断時は環境維持の旨 + 手動 down 手順を案内して終了 |

## 関連ケース

- case-13: 結果レビュー NEEDS REVISION → ids 再実行遡行の本体（実績 append-only の規範）
- case-25: PASS 時に down してワンサイクルを完結する主系
- case-27: up のまま残った環境を resume で再確認・再利用する分岐
