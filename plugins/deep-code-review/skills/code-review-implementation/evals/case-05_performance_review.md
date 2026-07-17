# case-05 パフォーマンス観点のレビュー

パフォーマンス重点のトリガーフレーズ（N+1 / メモリリーク）で本スキルが起動し、performance-reviewer を主担当としつつも 3 エージェントを並列起動することを検証するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "パフォーマンスに問題ないかレビューして、N+1やメモリリークを見て" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md description（使用場面）の「「パフォーマンスをレビューして」「N+1 / ブロッキング / メモリを見て」と言われた場合」、SKILL.md「前提」の観点表（パフォーマンス = performance-reviewer: N+1・ブロッキング・メモリ・状態管理機構肥大化）、SKILL.md「実行フロー」手順 2「3エージェントを 1メッセージ内で並列起動」、references/checklist.md セクション B O1。

**既存ケースとの差別化**: case-04 は実装正確性を含む総合トリガー、case-06 は Linter 単体トリガーを検証する。本ケースはパフォーマンス重点フレーズであっても、観点別スキルの規約（O1）に従い performance-reviewer 単独に絞らず 3 エージェントを並列起動する点を主眼とする。language-profiles 受領時の performance-reviewer への性能プロファイル適用は case-07 が担当する。

## 期待動作

- 起動フレーズ「パフォーマンスに問題ないかレビューして、N+1やメモリリークを見て」から code-review-implementation スキルが起動する（SKILL.md description の使用場面）
- performance-reviewer が N+1 クエリ・ブロッキング処理・メモリリーク・状態管理機構肥大化を重点評価する（SKILL.md「前提」の観点表）
- パフォーマンス重点依頼でも performance-reviewer 単独に絞らず、implementation-engineer / linter-static-analysis も 1 メッセージ内で並列起動する（SKILL.md「実行フロー」手順 2 / checklist.md O1）
- performance-reviewer が検出した性能問題・計測データ（あれば）を「### performance-reviewer」セクションに記載する（SKILL.md「出力フォーマット」）
- 「## 実装品質観点レビュー結果」構造で観点別中間レポートを返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-04: 実装正確性を含む総合トリガー（3 観点評価）
- case-06: 「Linter だけ実行して」フレーズでの起動（トリガー検証）
- case-07: language-profiles 受領時の performance-reviewer への性能観点プロファイル適用（O10）
