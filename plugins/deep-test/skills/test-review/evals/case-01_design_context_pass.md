# case-01 設計文脈 PASS（3 並列レビュー → 承認）

設計文脈でのレビューが Medium / Low 指摘のみで完了するケース。3 エージェントの並列起動・指摘統合・PASS 判定・review_status の承認処理までの流れを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `context=design target-slug=orderapp-web`（plan / cases は `{target-slug}/` 直下の既定パス） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・フルフローの設計レビュー） |
| 前提 | test-plan.md と test-cases.yaml（draft ケース 12 件・approved 0 件）が存在 / 各エージェントの指摘は統合後 Medium 2 件・Low 3 件（Critical / High なし） |

## 分岐の根拠

SKILL.md「実行フロー」1〜7 と「検証」（並列起動・共通注入事項・判定基準一致・書き換え範囲）、references/review-procedures.md 2 章（context=design 明示 → 設計文脈）・3.1 章（scope 未指定 → draft 全件）・3.2 章（3 並列とプロンプト構成）・3.4 章（承認処理）、references/review-criteria.md 2.1 章（Critical / High なし → PASS）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 1 章（設計文脈 = coverage / feasibility / user-perspective の 3 並列）・3 章（1 メッセージ内並列・総合判定はスキル責務）・4.3 章（共通注入事項）。

## 期待動作

- `deep-test:coverage-reviewer` / `deep-test:feasibility-reviewer` / `deep-test:user-perspective-reviewer` の 3 つを **1 メッセージ内で並列起動**する（逐次起動しない）
- 各プロンプトに共通注入事項ブロック（信頼度付与・未実施を問題なしと書かない・severity-policy / evidence-policy 準拠）と解決済みパス・レビュー対象ケース ID 一覧を含める
- 統合後の指摘（Medium 2 / Low 3）に Critical / High がないため **PASS** と判定する（エージェントの所見を転記せず、統合結果から本スキルが判定する）
- レビュー対象の draft ケース 12 件の `review_status` を `approved` へ Edit で更新し、`meta.updated_at` を更新する
- 更新後、対象ケースに draft が残っていないことを Grep で確認する
- 設計レビューレポート（判定 PASS・指摘一覧〔重要度降順 → 信頼度降順・出所併記〕・承認したケース ID 一覧・未確認事項）を返却する
- test-results.yaml に触れない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-cases.yaml の draft ケース 12 件の `review_status` を `approved` に更新 + `meta.updated_at` のみ（最小差分）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 判定 PASS・指摘一覧（Medium 2 / Low 3 を重要度降順 → 信頼度降順・出所併記で統合）・承認したケース ID 一覧・未確認事項の設計レビューレポート |
| 終了状態 | 設計文脈 PASS で 12 件の approved 反映完了（draft 残なしを Grep で確認）。総合判定はエージェントに委ねず本スキルが実施 |

## 関連ケース

- case-02: Critical / High 指摘ありで NEEDS REVISION
- case-04: 承認処理の書き換え範囲の詳細検証
