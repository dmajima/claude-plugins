# case-03 フロントエンドレビューフレーズでの起動（トリガー検証）

ユーザーが HTML / CSS の変更レビューを自然言語で依頼して本スキルを直接起動するケース。トリガー条件による起動と web-designer の基本フローを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "フロントエンドの変更をレビューして、HTML と CSS を見て" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 前提 | 差分に HTML / CSS の変更が含まれる（language-profiles 引数は未受領） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「フロントエンドをレビューして」「HTML / CSS / Vue / JS の変更を見て」と言われた場合」、SKILL.md「実行フロー」手順 2（web-designer の起動）、references/checklist.md セクション B O1 / O8（単独実行時は本スキル自身で progress.md を作成・維持）。委譲経由（case-01）との差は 起動形態 が 単独 である点。

## 期待動作

- トリガーフレーズ「フロントエンドの変更をレビューして、HTML と CSS を見て」から本スキルが単独起動する（SKILL.md「トリガー条件」）
- web-designer エージェントを起動する（checklist.md O1）
- HTML 構造・セマンティクス / CSS 設計・命名・スタイル衝突 / アクセシビリティ（WCAG）/ レスポンシブ対応を評価する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-2）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8）
- language-profiles 未受領のため language-detection.md で言語・FW を自己検出してプロンプトに含める（O10。詳細な自己検出経路は case-06）
- 中間レポートは「## フロントエンド観点レビュー結果」+「### web-designer」の構造で返却する（checklist.md C-Auto-1 / O2）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-01: 委譲（UI 変更あり）— 委譲経由の対比
- case-04: アクセシビリティ確認フレーズでの起動（別トリガー）
- case-06: language-profiles 未受領時の自己検出（O10・詳細）
