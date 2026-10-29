# case-14 resume 起動で中断 run なし（run-only 相当の提案）

`resume` で起動されたが中断 run（in_progress / interrupted）が存在しない場合に、エラーやでっち上げをせず、approved ケースがあることを確認して run-only 相当（Phase 4 から）を提案することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「resume」（または `/deep-test:test resume`） |
| 前提 | `{base}/{target-slug}/` に test-cases.yaml（approved ケースあり）と test-results.yaml が存在。runs[] はすべて status=completed（in_progress / interrupted の run が 1 件もない）。対話モード |

## 分岐の根拠

SKILL.md「実行モード判定」（再開: resume → 復帰位置判定は flow-resume.md 5 章）、references/flow.md 1 章（Resume判定 → Phase 4: 中断 run なし・approved ケースあり〔run-only 相当を提案〕/ Resume判定 → Phase 2: test-cases.yaml なし〔フルフローを案内〕）、references/flow-resume.md 5.1（判定手順: Phase 0 を省略せず実施 → summary で in_progress / interrupted の run を抽出 → 中断 run がなく approved ケースがある場合は run-only 相当〔Phase 4 から〕を提案する）、プラグイン共通 references/retest-policy.md 6 章（resume 対象 run = status が in_progress または interrupted の run）。

## 期待動作

- Phase 0（target-slug 解決・venv 準備・init）を resume でも省略せずに実施する（flow-resume.md 5.1 手順 1）
- `results_manager.py summary` を実行し、`runs[]` に in_progress / interrupted の run がないことを機械的に確認する（推測で「中断 run がある」ことにしない）
- 存在しない中断 run の再開を装わない: 過去の completed run の run_id を引き継いだ record 追記や、新規 run の勝手な開始（start-run の無断実行）をしない
- test-cases.yaml に approved ケースがあることを確認し、「再開対象の中断 run はないが実行可能な状態」である旨を説明したうえで **run-only 相当（Phase 4 から）を提案**する（提案であり、ユーザー確認なしに実行へ進まない）
- 提案が受け入れられた場合は Phase 4（select → 3 ゲート）から通常どおり進行する（新規 run_id は start-run が採番）
- 対比（別前提の分岐）: test-cases.yaml 自体が存在しない場合は resume 対象なしとして**フルフロー（Phase 2 から）を案内**する（flow-resume.md 5.1 の残り分岐。本ケースの主前提とは区別する）
- `validate` の `resumable_runs` が空であることと整合した判断をする（中断 run なしの機械的裏付け）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 提案時点では生成なし（start-run 未実行・実績未変更）。提案受諾後は通常フローどおり test-results.yaml（results_manager.py 経由）を更新 |
| 標準出力（要約） | 「中断 run は存在しない（全 run completed）」の確認結果と、approved ケースがあるため run-only 相当（Phase 4 から）で実行できる旨の提案。test-cases.yaml 不在の場合はフルフローの案内 |
| 終了状態 | 中断 run の再開はせず提案で待機（ユーザー受諾後に Phase 4 から進行）。実績はユーザー判断まで未変更 |

## 関連ケース

- case-03: 中断 run が存在する resume の正常系（Phase 5 から run_id 引き継ぎで継続する側）
- case-08: run-only モードの本体挙動（本ケースの提案先フロー）
- case-01: test-cases.yaml 不在時に案内するフルフローの本体挙動
