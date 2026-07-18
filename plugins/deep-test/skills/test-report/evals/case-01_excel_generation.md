# case-01 Excel 生成正常系（対話・バリデーション通過）

実績 YAML が完全（fail の defect 3 点セット充足・scope/results 整合・エビデンス実在・マスク済み）な状態で、
対話モードで Excel を選択して報告書を生成する正常系フロー全体を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | オーケストレータ `test` の report フェーズから Skill ツール経由で委譲（対話モード・target-slug 確定済み） |
| 前提 | `{target-slug}/test-results.yaml`（run 1 件以上・fail 1 件以上、defect 3 点セット完備）と `test-cases.yaml` が存在。venv 構築可能 |
| 形式選択 | AskUserQuestion で「Excel」を選択 |

## 分岐の根拠

SKILL.md「実行フロー」ステップ 1〜6（validate → evidence-auditor → 形式選択 → 生成 → 返却）、
`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 2 章（最終バリデーション通過後のみ生成可）、
`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（対話時の形式選択）・2 章（ファイル命名）・3 章（Excel 構成）、
`${CLAUDE_PLUGIN_ROOT}/references/agents.md`（evidence-auditor 単独起動・共通注入事項）。

## 期待動作

- 生成前に results_manager.py の `validate` を venv Python で実行し、通過を確認してから次へ進む（SKILL.md ステップ 2）
- evidence-auditor を Agent ツールで起動し、プロンプトに agents.md 4.3 の共通注入事項（信頼度付与・未確認を問題なしとしない等）を含める（SKILL.md ステップ 3）
- AskUserQuestion で Excel / Markdown の選択肢を提示し、Excel 選択を受けて `${CLAUDE_SKILL_DIR}/references/scripts/report/generate_excel.py` を venv で実行する（SKILL.md ステップ 4〜5、references/procedures.md 2 章）
- 出力先はセッション作業領域直下・ファイル名は `test-report_{target-slug}_{yyyyMMdd}.xlsx`（report-format.md 2 章）
- 生成されるシートは「サマリ」「推移」+ 実施レベルのみのレベル別シート（report-format.md 3.1。スクリプトが保証）
- 返却は SKILL.md「引き渡し」の正常時フォーマット（報告書絶対パス・総合判定・集計・NG 件数・未確認事項件数）。集計値はスクリプト標準出力の転記であり、LLM が手計算しない（SKILL.md「検証」）
- test-results.yaml を Edit / Write で編集しない（SKILL.md「重要な制約」）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 報告書 1 ファイル `test-report_{target-slug}_{yyyyMMdd}.xlsx`（セッション作業領域直下）。test-results.yaml は読み取りのみ |
| 標準出力（要約） | SKILL.md「引き渡し」正常フォーマット（報告書絶対パス・総合判定・集計〔latest〕・NG 件数・未確認事項件数。集計はスクリプト出力の転記） |
| 終了状態 | 生成完了 |

## 関連ケース

- case-02: Markdown 選択時の対応分岐
- case-03: バリデーション違反時（本ケースの前段ゲートで止まる分岐）
- case-05: 複数レベル実施時のシート分け詳細
