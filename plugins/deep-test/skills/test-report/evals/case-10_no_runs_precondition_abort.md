# case-10 実績 run が 0 件（前提「run ≥ 1 件」違反 → 生成中断・差し戻し）

報告対象の `test-results.yaml` に run が 1 件も記録されていない（または `test-results.yaml` が不在 / 空）場合、報告書を生成せずに前提不成立として中断し、テスト実行を案内することを検証する。SKILL.md「前提」が要求する「run が 1 件以上記録されている」を満たさない状態での挙動を、空の報告書生成・実績の捏造なしで扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | `report-only`（`/deep-test:test-report`）またはユーザー直接起動（対話 / 非対話いずれでも同一挙動） |
| 前提 | 対象 `{target-slug}/` は解決できる（test-cases.yaml は存在しうる）が、`test-results.yaml` に run が **0 件**（`runs: []` / ファイル不在 / 実行前で latest 未生成）。まだ一度もテスト実行（start-run → record → finish-run）が行われていない |

## 分岐の根拠

SKILL.md「前提」（`{target-slug}/test-results.yaml` が存在し、run が **1 件以上**記録されている）、SKILL.md「実行フロー」1（入力確認・報告対象確定）・2（最終バリデーション）、SKILL.md「検証」（validate が実行不能・前提不成立の場合は生成に進まず中断・報告する）、SKILL.md「引き渡し」差し戻しフォーマット、`${CLAUDE_PLUGIN_ROOT}/references/report-format.md` 1 章（事前検証未通過での生成は禁止）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 5 章（集計は latest 採用。latest が無ければ集計対象が無い）。

## 期待動作

- 入力確認（ステップ 1）で報告対象の run を特定しようとし、`test-results.yaml` に run が 0 件（または不在 / 空）であることを検出する
- **前提「run ≥ 1 件」の不成立**として、報告書生成に進まない（validate・evidence-auditor 監査・形式選択の AskUserQuestion にも進まない・generate_excel.py / generate_markdown.py を実行しない）
- 「報告対象の run が記録されていないため報告書を生成できない」旨と、先にテストを実行する案内（`/deep-test:test`〔フルフロー〕/ 既存ケースがあれば `run-only` / `retest`）を、SKILL.md「引き渡し」の差し戻しフォーマットで返却する
- **空の報告書を生成しない・0 件を「問題なし」「PASS」と結論しない**（未実施を成功と偽装しない）
- 実績を自分で作らない（start-run / record は行わない = test-report の責務外。書き込みはオーケストレータの責務）
- test-results.yaml / test-cases.yaml を Edit / Write しない（読み取りのみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（報告書を生成しない。test-results.yaml も作成・修正しない） |
| 標準出力（要約） | SKILL.md「引き渡し」差し戻しフォーマット（中断理由〔前提不成立: 報告対象の run が 0 件〕・必要な対応〔先に `/deep-test:test` 等でテストを実行して run を記録する〕） |
| 終了状態 | 生成中断（前提不成立の差し戻し。空報告書を作らない・実績を捏造しない） |

## 関連ケース

- case-03: run はあるが defect 3 点セット欠落・scope/results 不整合で差し戻す側（本ケースは run 自体が 0 件で前提不成立）
- case-01 / case-02: run が 1 件以上あり正常に生成する側（本ケースの前提が満たされた対）
- case-06: 単独起動での target-slug 解決（本ケースは run 0 件の前提不成立を扱う）
