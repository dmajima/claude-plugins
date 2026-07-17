# case-01 委譲・テスト実行可能（GREEN / RED 報告）

code-review オーケストレーターから委譲され、ユニットテスト基盤と実行権限が揃っているケース。2 エージェント並列起動と test-runner の実行ステータス報告（GREEN / RED）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard`（テストプロジェクト情報を含む） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | ユニットテストプロジェクトが存在し、`Bash(dotnet *)` 等の実行権限が許可済み |

## 分岐の根拠

SKILL.md「動的検証」の「`test-runner` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する」、SKILL.md「実行フロー」手順 2「2エージェントを 1メッセージ内で並列起動」、SKILL.md「出力フォーマット」（実行ステータス: GREEN | RED | SKIPPED / 失敗したテスト（RED時）: ファイル:メソッド・失敗理由）、references/checklist.md セクション B O1 / O2 およびセクション C C-Auto-1 / C-Auto-2。

## 期待動作

- test-engineer / test-runner の 2 エージェントを 1 メッセージ内で並列起動する（references/checklist.md O1）
- test-runner は許可された Bash 権限でユニットテストを実行し、実行コマンドを中間レポートに記録する（SKILL.md「動的検証」「出力フォーマット」）
- 中間レポートに「実行ステータス: GREEN」または「実行ステータス: RED」を明示する（checklist.md C-Auto-2）
- RED 時は失敗したテストをファイル:メソッド・失敗理由付きで列挙する（SKILL.md「出力フォーマット」）
- test-engineer はユニットテストの網羅性・エッジケース・モック過剰・命名・AAA パターン遵守を評価する（SKILL.md「前提」の観点表）
- 中間レポートは「## テスト観点レビュー結果」+「### test-engineer」「### test-runner」の構造で返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9 / SKILL.md「重要な制約」）

## 関連ケース

- case-02: テスト基盤なし・権限なし（SKIPPED 記録）
- case-03: E2E テスト実行依頼（スコープ外明示）
