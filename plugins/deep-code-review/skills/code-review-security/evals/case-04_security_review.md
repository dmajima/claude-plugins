# case-04 セキュリティレビューフレーズでの起動（トリガー検証）

ユーザーが自然言語のセキュリティレビュー依頼で本スキルを直接起動するケース。トリガー条件による起動と 2 エージェント並列起動の基本フローを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "セキュリティの観点でコードをレビューして" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 前提 | レビュー対象の差分・プロジェクト規約サマリは会話文脈から取得（language-profiles 引数は未受領） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「セキュリティをレビューして」「OWASP / STRIDE で確認して」と言われた場合」、SKILL.md「実行フロー」手順 2（2 エージェントを 1 メッセージ内で並列起動）、references/checklist.md セクション B O1 / O8（単独実行時は本スキル自身で progress.md を作成・維持）。委譲経由（case-01）との差は 起動形態 が 単独 である点。

## 期待動作

- トリガーフレーズ「セキュリティの観点でコードをレビューして」から本スキルが単独起動する（SKILL.md「トリガー条件」）
- security-engineer / dependency-safety の 2 エージェントを 1 メッセージ内で並列起動する（references/checklist.md O1）
- security-engineer は OWASP / STRIDE に基づく脅威モデリング・脆弱性評価を実施する（SKILL.md「出力フォーマット」）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8）
- language-profiles 未受領のため language-detection.md で言語・FW を自己検出してエージェントプロンプトに含める（O10。詳細な自己検出経路は case-08）
- 中間レポートは「## セキュリティ観点レビュー結果」+「### security-engineer」「### dependency-safety」の構造で返却する（checklist.md C-Auto-1 / O2）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-01: 委譲・脆弱性スキャン実行可能（EXECUTED）— 委譲経由の対比
- case-05: 依存脆弱性確認フレーズでの起動（別トリガー）
- case-08: language-profiles 未受領時の自己検出（O10・詳細）
