# case-03 レベル指定あり（提案・確認の省略と不整合警告）

`levels=` で対象レベルが明示指定されたケース。レベル提案と AskUserQuestion を省略して指定を採用し、分析結果との明らかな不整合には警告を付すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=inventory-app 対象説明=./ levels=functional,integration-external` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | 対象リポジトリに画面実装はあるが、外部システム・外部 API 連携が**存在しない**（integration-external の根拠がない） |

## 分岐の根拠

SKILL.md「実行フロー」3（`levels=` 指定があれば採用・明らかな不整合は警告）、references/design-procedures.md 4 章（`levels=` 指定時も明らかな不整合は警告を返却に含める。指定自体は尊重する）・4.1 章（外部 IF が無ければ integration-external を含めない、という提案時の判定目安が不整合検知の根拠になる）。

## 期待動作

- レベル提案の作成・AskUserQuestion による確定を行わず、指定された `functional` / `integration-external` を採用する
- 対象分析で外部 IF が存在しないことを確認し、`integration-external` 指定との不整合を**警告として返却に含める**（指定を勝手に削除・変更しない）
- `integration-external` のケースは、分析で確認できた範囲の設計に留め、外部接続先が不明である旨を未確認事項に記載する
- test-plan.md のレベル別スコープに、指定採用である旨と警告内容を記録する
- ID プレフィクスは指定レベルに対応する `TC-FUNC-` / `TC-ITB-` を使用する（yaml-schema.md 2.2 章の対応表）
- test-architect 自己チェックのプロンプトにレベル選定案（指定採用 + 警告）を含め、選定妥当性の評価を受ける

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/test-plan.md`（レベル別スコープに指定採用の旨と警告内容を記録）・`test-cases.yaml`（全ケース `review_status: draft`、`TC-FUNC-` / `TC-ITB-` の採番）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 生成結果のサマリに加え、`integration-external` 指定と分析結果（外部 IF なし）の不整合警告、外部接続先不明を未確認事項として明記 |
| 終了状態 | 指定レベルを尊重（削除・変更しない）したまま全ケース `review_status: draft` で委譲元へ返却。後続の設計レビューへ |

## 関連ケース

- case-01: レベル未指定（提案 → AskUserQuestion 確定）
- case-05: 非対話でのレベル自動採用
