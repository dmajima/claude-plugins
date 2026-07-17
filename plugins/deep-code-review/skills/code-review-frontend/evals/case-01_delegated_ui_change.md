# case-01 オーケストレーター委譲（UI 変更あり）

code-review オーケストレーターから標準モードで委譲されたケース（UI 変更あり時のみ委譲される）。web-designer の起動と、観点項目を網羅した中間レポートの返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ（.vue / .css / .liquid 等の変更を含む）> <プロジェクト規約サマリ> mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由・標準モード・UI 変更あり時） |

## 分岐の根拠

SKILL.md「トリガー条件」の「code-review オーケストレーターから Skill ツール経由で委譲された場合（標準モード・UI 変更あり時）」、SKILL.md「動的に省略可（責務はオーケストレーター）」の注記「本スキルが呼ばれたら 必ずレビューを実行する。スキル自体を呼ぶか否かの判断は `code-review` オーケストレーター側で行う」、SKILL.md「実行フロー」手順 2（web-designer の起動）、references/checklist.md セクション B O1（web-designer エージェントを起動している（単独））およびセクション C C-Auto-1 / C-Auto-2（観点項目 HTML / CSS / アクセシビリティ|WCAG / レスポンシブ / Vue|Liquid|JS の網羅性）。

## 期待動作

- 呼ばれた以上は必ずレビューを実行し、本スキル内で実行可否を再判断しない（SKILL.md「動的に省略可」注記）
- web-designer エージェントを起動する（references/checklist.md O1。本スキルの内部エージェントは 1 体のため並列化は不要）
- 中間レポートは「## フロントエンド観点レビュー結果」+「### web-designer」の構造で返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- HTML 構造・セマンティクス / CSS 設計・命名・スタイル衝突 / アクセシビリティ（WCAG）/ レスポンシブ / Vue.js・Liquid・JS の観点項目を網羅して言及する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-2）
- プロジェクト規約（CLAUDE.md / .stylelintrc / .eslintrc / 既存デザインシステム）を最優先評価基準にし、指摘の根拠に引用する（checklist.md O6）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9 / SKILL.md「重要な制約」）
- レビュー対象ソースコードを Write ツールで変更しない（SKILL.md「重要な制約」）

## 関連ケース

- case-02: 単独実行 + スコープ外（バックエンド / XSS 等）の混在
