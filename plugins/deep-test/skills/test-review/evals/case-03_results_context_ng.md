# case-03 結果文脈（NG あり）

実行結果に fail を含む結果レビューのケース。2 エージェントの並列起動、原因分類・再現手順完全性・severity 妥当性の検証、report フェーズへの引き継ぎ事項の返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `context=results target-slug=orderapp-web run=R20260717-143000` + 実行結果サマリ（functional: 対象 10 / pass 8 / fail 2） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・run 後の結果レビュー） |
| 前提 | test-results.yaml に対象 run の fail 2 件（defect 付き）が記録済み。うち 1 件は severity: medium だが他ユーザーの情報が閲覧できる内容（過小評価）、もう 1 件は reproduction_steps に環境情報がない |

## 分岐の根拠

SKILL.md「責務」の文脈表（結果文脈 = defect-analyst / user-perspective-reviewer の 2 並列）と「重要な制約」（test-results.yaml は読み取り専用・severity 補正は提案）、references/review-procedures.md 2 章（context=results → 結果文脈）・4.1〜4.4 章（fail 抽出・2 並列・検証観点・引き継ぎ事項）、references/review-criteria.md 4 章（結果文脈はゲート判定なし・引き継ぎ事項の必須項目）、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` 1 章（結果レビューの起動構成）・4.2 章（defect-analyst への defect 詳細と severity-policy 参照指示）、`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md`（妥当性検証の判定基準）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 1 章（3 点セット要件）。

## 期待動作

- test-results.yaml を Read で読み取り、対象 run（R20260717-143000）の fail 2 件の defect 詳細・エビデンスパス一覧を抽出する（Edit / Write を実行しない）
- `deep-test:defect-analyst` / `deep-test:user-perspective-reviewer` の 2 つを **1 メッセージ内で並列起動**する（設計文脈の 3 構成を誤って使わない）
- defect-analyst のプロンプトに fail 全件の defect 詳細・エビデンスパス一覧・severity-policy.md の参照指示、user-perspective のプロンプトに実行結果サマリを含める。両方に共通注入事項ブロックを含める
- 検証結果として以下を返す: 情報閲覧の欠陥の severity 補正案（medium → critical / high、severity-policy.md の該当基準を根拠に）/ 環境情報欠落の再現手順不備（evidence-policy.md 1 章の要件未充足）
- PASS / NEEDS REVISION の判定を行わない（結果文脈にゲートはない）
- report フェーズへの引き継ぎ事項（報告書への注記・エビデンス補完の要否・severity 補正案〔case_id / 現行値 → 提案値 / 根拠〕）を含む結果レビューレポートを返却する
- test-results.yaml の severity・記録を書き換えない（補正は提案のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（test-results.yaml は読み取り専用のため severity・記録を書き換えない。test-cases.yaml も書き換えない） |
| 標準出力（要約） | 結果レビューレポート: severity 補正案（medium → critical / high を case_id / 現行値 → 提案値 / 根拠付きで提示）・環境情報欠落の再現手順不備の指摘・report フェーズへの引き継ぎ事項（報告書への注記・エビデンス補完の要否） |
| 終了状態 | PASS / NEEDS REVISION の判定なし（結果文脈にゲートはない）。補正は提案のみで引き継ぎ事項の返却をもって完了 |

## 関連ケース

- case-01 / case-02: 設計文脈のゲート判定（結果文脈との構成差の対）
- case-05: 文脈判定の曖昧ケース
