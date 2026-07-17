# case-04 テストコード品質のレビュー

テスト品質観点のトリガーフレーズ（「テストコードをレビューして」「網羅性を確認して」）で本スキルが起動し、test-engineer / test-runner を並列起動してテストコード品質を評価することを検証するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "テストコードをレビューして、網羅性を確認して" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「テストコードをレビューして」「テスト網羅性を確認して」…と言われた場合」、SKILL.md「実行フロー」手順 2「2エージェントを 1メッセージ内で並列起動」、SKILL.md「前提」の観点表（テストコード品質 = test-engineer: 網羅性・エッジケース・モック過剰・命名・AAA パターン遵守 / ユニットテスト実行 = test-runner）、references/checklist.md セクション B O1。

**既存ケースとの差別化**: case-01 / case-02 は委譲経路で test-runner の EXECUTED / SKIPPED を主眼とし、case-05 は「ユニットテストを実行して」の runner 実行トリガーを主眼とするのに対し、本ケースは test-engineer によるテストコード品質の静的レビュー（網羅性・AAA 等）を主眼とするトリガーフレーズの成立を検証する。

## 期待動作

- 起動フレーズ「テストコードをレビューして、網羅性を確認して」から code-review-testing スキルが起動する（SKILL.md「トリガー条件」）
- test-engineer / test-runner の 2 エージェントを 1 メッセージ内で並列起動する（SKILL.md「実行フロー」手順 2 / checklist.md O1）
- test-engineer がテスト網羅性・エッジケース・モック過剰・命名・AAA パターン遵守を評価する（SKILL.md「前提」の観点表）
- test-runner は対応 Bash 権限があればユニットテストを実行し、なければ SKIPPED を理由付きで記録する（SKILL.md「動的検証」/ checklist.md O3）
- 「## テスト観点レビュー結果」+「### test-engineer」「### test-runner」の構造で観点別中間レポートを返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-01: 委譲・テスト実行可能（GREEN / RED 報告）
- case-05: 「ユニットテストを実行して」フレーズでの起動（runner 実行トリガー）
