# case-02 再テスト ng-only（select 抽出・実績マージ・回帰非代替注記）

実績のある対象への ng-only 再テストで、対象判定マトリクスに従う機械的抽出・設計フェーズの省略・append マージ・回帰非代替の注記を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「NG だったケースだけ再テストして」（または `/deep-test:test-retest` → ng-only 選択） |
| 前提 | `{base}/{target-slug}/` に test-cases.yaml と test-results.yaml が存在。latest は fail 2 件・blocked 1 件・skipped 1 件・pass 5 件。前回実行後に追加された未実行ケース 1 件（approved）と draft ケース 1 件がある |

## 分岐の根拠

SKILL.md「実行モード判定」（再テスト: Phase 0→(1 必要時)→4→5→6→7）、SKILL.md「重要な制約」（select を経ない対象確定禁止）、プラグイン共通 references/retest-policy.md 2 章（対象判定マトリクス: ng-only は fail / blocked / skipped + 未実行が対象）・3 章（回帰非代替）・4 章（承認済みケースゲート）・7 章（append + latest 更新の実績マージ）。

## 期待動作

- 設計フェーズ（Phase 2〜3）は起動しない（test-design / test-review〔設計文脈〕への Skill 起動なしで Phase 4 へ進む）
- `results_manager.py select --mode ng-only` を実行し、出力の `cases` に fail 2 件・blocked 1 件・skipped 1 件・未実行（approved）1 件が含まれ、pass 5 件が含まれないことを前提に scope を確定する（LLM の判断で対象を追加・除外しない）
- select 出力の `draft_cases`（draft 1 件）が空でないため、実行前に test-review（設計文脈）による承認を要求する（承認済みケースゲート）
- 人間承認ゲート・MCP ゲートを経て `start-run --mode ng-only` で**新規 run_id** を採番する（既存 run の使い回し・上書きをしない）
- 結果は record による append + latest 更新でマージし、既存の runs / results エントリを書き換えない
- 引き渡しに「ng-only は回帰テストの代替ではない。修正の副作用検出には full を推奨」の注記を含める（報告書側の注記は test-report が report-format 規約で出力）
- skipped だったケースが環境整備後に pass すれば、latest 集計上 pass として扱われる（推移は run 横断データで保持）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（results_manager.py の start-run〔新規 run_id〕→ record〔append + latest 更新〕→ finish-run で更新。既存 runs / results は書き換えず、Edit / Write の直接編集なし）・報告書（test-report がセッション作業領域直下に生成）。draft 1 件はゲート承認時に test-cases.yaml 上で approved 化 |
| 標準出力（要約） | SKILL.md「引き渡し」の正常完了フォーマット: run_id・レベル別集計（summary）・報告書パス・未確認事項に加え「ng-only は回帰テストの代替ではない。full を推奨」の注記 |
| 終了状態 | 再テストモード（Phase 2〜3 省略）で Phase 7 まで完了。新規 run_id の run status=completed |

## 関連ケース

- case-01: フルフロー（設計フェーズを含む分岐と対）
- case-05: 非対話時の target-slug 複数エラー（本ケースは対話で slug 選択）
- case-06: 再テスト中の fail 記録でも同じ一次バリデーションが働く
