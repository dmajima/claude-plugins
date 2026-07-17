# case-04 実装品質のレビュー

実装品質観点の代表的なトリガーフレーズ（「実装の品質をレビューして」「コードの正確性を確認して」）で本スキルが起動し、3 エージェントを並列起動して 3 観点（実装正確性・コーディング規約・パフォーマンス）を評価することを検証するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "実装の品質をレビューして、コードの正確性を確認して" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「実装品質をレビューして」「コードの正確性を確認して」…と言われた場合」（フレーズ → 本スキル起動）、SKILL.md「実行フロー」手順 2「3エージェントを 1メッセージ内で並列起動」、SKILL.md「前提」の観点表（実装正確性 = implementation-engineer / コーディング規約・整形 = linter-static-analysis / パフォーマンス = performance-reviewer）、references/checklist.md セクション B O1。

**既存ケースとの差別化**: 同種フレーズを扱う case-03 は「単独実行 + 動的検証権限なしの SKIPPED 記録 + progress.md 自スキル作成」を主眼とするのに対し、本ケースは対話起動でのトリガー成立と 3 エージェント並列起動・3 観点評価の成立自体を検証する（SKIPPED / progress.md は扱わない）。パフォーマンス単体・Linter 単体のフレーズ分岐は case-05 / case-06 が担当する。

## 期待動作

- 起動フレーズ「実装の品質をレビューして、コードの正確性を確認して」から code-review-implementation スキルが起動する（SKILL.md「トリガー条件」）
- implementation-engineer / linter-static-analysis / performance-reviewer の 3 エージェントを 1 メッセージ内で並列起動する（SKILL.md「実行フロー」手順 2 / checklist.md O1）
- ロジックの正しさ・例外処理・契約整合性（implementation-engineer）、コーディング規約・整形・型違反（linter-static-analysis）、N+1・ブロッキング・メモリ（performance-reviewer）を各担当観点として評価する（SKILL.md「前提」の観点表）
- 「## 実装品質観点レビュー結果」+「### implementation-engineer」「### linter-static-analysis」「### performance-reviewer」の構造で観点別中間レポートを返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- Finding ID（CR-NNN）の採番・Verdict 判定・統合サマリ生成は行わない（checklist.md O9 / SKILL.md「重要な制約」。オーケストレーター責務）

## 関連ケース

- case-03: 同種フレーズの単独実行（動的検証 SKIPPED・progress.md 自スキル作成）
- case-05: パフォーマンス観点フレーズでの起動（トリガー検証）
- case-06: 「Linter だけ実行して」フレーズでの起動（トリガー検証）
