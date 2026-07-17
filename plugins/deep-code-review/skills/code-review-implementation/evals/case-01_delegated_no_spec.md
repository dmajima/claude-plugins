# case-01 オーケストレーター委譲（spec_summary なし・動的検証権限あり）

code-review オーケストレーターから委譲され、仕様書サマリの指定がなく、Linter 系の動的検証権限が許可されているケース。3 エージェント並列起動・仕様整合性チェックのスキップ・動的検証 EXECUTED を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard`（`spec_summary` なし） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | `Bash(dotnet *)` 等の動的検証用権限が許可済み |

## 分岐の根拠

SKILL.md「実行フロー」手順 2「3エージェントを 1メッセージ内で並列起動」、SKILL.md「仕様整合性チェック（仕様書指定時のみ）」の「仕様書未指定時はこの観点をスキップし、規約観点のみで評価する」、SKILL.md「動的検証」の「`linter-static-analysis` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する」、references/checklist.md セクション B（O1 / O2 / O7 / O9）。

## 期待動作

- implementation-engineer / linter-static-analysis / performance-reviewer の 3 エージェントを 1 メッセージ内で並列起動する（references/checklist.md O1）
- `spec_summary` 未指定のため、仕様整合性チェック（実装漏れ・仕様逸脱・仕様矛盾）は評価せず、規約観点のみで評価する（SKILL.md「仕様整合性チェック（仕様書指定時のみ）」/ checklist.md O7）
- linter-static-analysis は許可された Bash 権限で実コマンドを実行し、中間レポートに「動的検証: EXECUTED」と記録する（SKILL.md「動的検証」）
- 中間レポートは「## 実装品質観点レビュー結果」+「### implementation-engineer」「### linter-static-analysis」「### performance-reviewer」の構造で返却する（SKILL.md「出力フォーマット」が SSOT。checklist.md C-Auto-1 の自動検証スクリプトで必須セクションを確認）
- 重複指摘は最も重い重要度を採用し、指摘ごとに必須項目（致命度・指摘箇所・指摘内容・求める修正・理由・根拠）を漏れなく含める（SKILL.md「実行フロー」手順 4）
- Finding ID（CR-NNN）の採番・Verdict 判定・統合サマリ生成は行わない（checklist.md O9 / SKILL.md「重要な制約」。オーケストレーター責務）
- レビュー対象ソースコードを Write ツールで変更しない（SKILL.md「重要な制約」）

## 関連ケース

- case-02: spec_summary 指定あり（仕様整合性チェックを追加評価）
- case-03: 単独実行・動的検証権限なし（SKIPPED 記録）
