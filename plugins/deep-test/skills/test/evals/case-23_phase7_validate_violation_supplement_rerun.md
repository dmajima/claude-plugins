# case-23 Phase 7 最終 validate の scope 突合違反 → Phase 5 復帰で欠落ケースを補完再実行

Phase 7 の最終バリデーション validate が、当該 run の scope に含まれる 1 ケースの記録欠落（scope vs results 突合の不一致）を検出した場合に、報告書生成へ進まず flow.md の遷移 `Phase7 --> Phase5` に従って Phase 5 へ復帰し、欠落ケースのみを同一 run_id で補完再実行 → finish-run 再確定 → Phase 7 再実行（validate が ok）を経てから test-report を起動することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 状況 | フルフローの Phase 7。Phase 5 で全レベル実行後に finish-run を実行したが、1 ケース（TC-FUNC-003）の record 漏れにより当該 run が完全化していない。Phase 6（結果レビュー）通過後、Phase 7 手順 1 の validate が scope vs results 突合で TC-FUNC-003 の記録欠落を violation として検出する |
| 前提 | 対話モード。検出された違反は fail の defect 3 点セット欠落ではなく、**記録そのものの欠落**（scope に含まれるのに results に結果エントリがない）。他ケースの結果は record 済み |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章 状態遷移図（`Phase7 --> Phase5: validate 違反（欠落補完の再実行）`）・2 章 Phase 7 入出力（`validate` → `Skill: test-report`）・6 章 Phase 7 手順 1（最終バリデーション。違反があれば報告書生成へ進まず差し戻す）・Phase 5 手順 3〜4（同一 run_id で record → finish-run 再確定）、SKILL.md「実行フロー」Phase 7（`validate` 違反があれば差し戻して生成しない）・「検証」（`validate` が ok〔violations 0 件〕である）、プラグイン共通 `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 最終段（validate = 全 fail の 3 点セット再検証 + run の scope vs results 突合〔欠落ケース検出〕→ 報告書生成を中断し差し戻す〔欠落エビデンスの補完、または該当 run の状態確認へ〕）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md`（validate の `violations`〔`{type, run_id, case_id, detail}`〕構造）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md`（append-only・重複 record は exit 2 で拒否）。

## 期待動作

- Phase 7 手順 1 で `validate` を実行し、`violations` に scope vs results 突合の欠落ケース（TC-FUNC-003 の記録欠落）を受け取る
- **違反があるため報告書生成へ進まない**（test-report を起動しない。evidence-policy.md 最終段の生成中断・差し戻し）。finish-run が先に completed 相当を返していたとしても、最終 validate を権威ある最終ゲートとして扱い、その違反を看過しない
- flow.md 1 章の遷移 `Phase7 --> Phase5` に従い **Phase 5 へ復帰**する（欠落補完の再実行）
- 欠落ケース **TC-FUNC-003 のみ**を対象に、そのレベルの実行スキル（TC-FUNC = test-run-functional）へ再委譲する。**run_id を新規採番せず、当該 run の run_id をそのまま引き継ぐ**（同一 run への欠落補完 = append。ids 再テストのような新規 run 採番ではない）
- 実行スキルの中間結果 JSON を受領して record する。fail の場合は defect 3 点セットの一次バリデーション（record exit 2 → 追加取得 → 再 record。case-06 と同一）を適用する
- 既に record 済みのケースを再実行・再記録しない（結果は append-only で不変。重複 record は exit 2 で拒否される）
- 欠落ケースの結果を推測・創作で埋めない（実行して実結果を record する）
- 補完後に `finish-run` を再実行して run を再確定する
- Phase 7 を再実行する: `validate` を再度実行し、`violations` 0 件（ok）を確認してから test-report を起動する（SKILL.md「検証」の validate が ok である を満たしてから生成する）
- 一連の補完は同一 run_id 内で完結し、新規 run を作らない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（欠落ケース TC-FUNC-003 の結果を**同一 run_id に append**。既存 results の書き換え・削除なし・latest は再記録で更新）。validate が ok になった後にのみ報告書を生成 |
| 標準出力（要約） | validate の scope 突合違反（TC-FUNC-003 の記録欠落）を検出し、生成せず Phase 5 へ復帰して同一 run_id で補完した経過。補完・再 validate 通過後は SKILL.md「引き渡し」の正常フォーマット（run_id・レベル別集計・報告書パス・未確認事項） |
| 終了状態 | 同一 run_id で欠落補完 → finish-run 再確定 → validate 再実行で ok → test-report 起動。違反を無視した報告書生成はしない |

## 関連ケース

- case-06: Phase 5 内の record 一次バリデーション（exit 2）による欠落取得（記録前・同一フェーズ内での fail 3 点セット欠落補完）。**本ケースは Phase 7 の最終 validate が scope 突合で「記録そのものの欠落」を検出して Phase 5 へ遡る点で別物**（発生フェーズ・違反種別・遡行の有無が異なる）
- case-13: 結果レビュー（Phase 6）NEEDS REVISION の遡行（ids 再実行 = 新規 run を採番）。本ケースは同一 run への欠落補完（新規 run を作らない）点が異なる
- case-03 / case-14: resume の途中復帰（中断 run の残ケースを同一 run_id で継続する点が近い。本ケースは Phase 7 validate 起点での復帰）
