# case-02 単独実行 + スコープ外観点の混在（振分け）

ユーザーが本スキルを直接起動し、差分にバックエンド実装等のフロントエンド以外の変更が混在するケース。progress.md の自スキル作成と、スコープ外観点の対応スキルへの振分けを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "アクセシビリティを確認して" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 前提 | 差分に UI 変更（.vue / .css）とバックエンド API 実装の変更が混在している |

## 分岐の根拠

SKILL.md「トリガー条件」の「「アクセシビリティを確認して」と言われた場合」、references/checklist.md セクション B O4（バックエンド実装・API 設計・XSS 重点レビュー・E2E テスト実行はスコープ外として明示）/ O8（オーケストレーター不在で単独実行された場合、本スキル自身で progress.md を作成・維持）およびセクション C C-Auto-3（スコープ外指摘の混入チェック）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 5（frontend 行: バックエンド → `code-review-implementation` / API 設計 → `code-review-architecture` / XSS 重点 → `code-review-security`）およびセクション 4（オーケストレーター不在時の進捗管理）。

## 期待動作

- トリガーフレーズ「アクセシビリティを確認して」から本スキルが単独起動する（SKILL.md「トリガー条件」）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8 / common-references.md セクション 4）
- web-designer はフロントエンド・UI/UX 観点（HTML / CSS / アクセシビリティ / レスポンシブ / Vue・Liquid・JS）のみをレビューする（SKILL.md「責務」「前提」の観点表）
- バックエンド実装に関する所見は `code-review-implementation`、API 設計は `code-review-architecture`、XSS 重点レビューは `code-review-security` へ誘導する（checklist.md O4 / common-references.md セクション 5）
- バックエンド / API / E2E 等のスコープ外観点を中間レポートに混入させない。混入を検出した場合はスコープ外フラグ付与または除外する（checklist.md C-Auto-3 / セクション D「O4」）
- 「別 PR で対応」「Issue を作成」等の文言を出力に含めない（checklist.md C-Auto-4 / universal-rules.md U8）

## 関連ケース

- case-01: 委譲（UI 変更のみ・スコープ外混在なし）
