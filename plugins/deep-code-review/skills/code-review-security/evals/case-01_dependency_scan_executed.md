# case-01 委譲・脆弱性スキャン実行可能（EXECUTED）

code-review オーケストレーターから委譲され、依存定義ファイルの差分とスキャン権限が揃っているケース。2 エージェント並列起動と dependency-safety の脆弱性スキャン実行（EXECUTED 記録）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard`（`*.csproj` / `package-lock.json` 等の依存定義ファイル差分を含む） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | `Bash(dotnet *)`（dotnet list package --vulnerable）や `Bash(npm *)`（npm audit）等のスキャン権限が許可済み |

## 分岐の根拠

SKILL.md「動的検証」の「`dependency-safety` は対応する Bash 権限が許可されている場合のみ脆弱性スキャンを実コマンドで実行する」、SKILL.md「実行フロー」手順 2「2エージェントを 1メッセージ内で並列起動」、SKILL.md「出力フォーマット」（動的検証: EXECUTED | SKIPPED / 検出した CVE / 既知脆弱性 / 破壊的変更・マイグレーションリスク）、references/checklist.md セクション B O1 / O3 / O4 およびセクション C C-Auto-1 / C-Auto-2。

## 期待動作

- security-engineer / dependency-safety の 2 エージェントを 1 メッセージ内で並列起動する（references/checklist.md O1）
- dependency-safety は許可された Bash 権限で脆弱性スキャンを実コマンド実行し、中間レポートに「動的検証: EXECUTED」と記録する（SKILL.md「動的検証」/ checklist.md C-Auto-2）
- 検出した CVE / 既知脆弱性、破壊的変更・マイグレーションリスクを中間レポートに記載する（SKILL.md「出力フォーマット」）
- security-engineer は検出した脅威・脆弱性を OWASP / STRIDE 分類で報告し、認証・認可・データ保護に関する指摘を記載する（SKILL.md「出力フォーマット」）
- 中間レポートは「## セキュリティ観点レビュー結果」+「### security-engineer」「### dependency-safety」の構造で返却する（checklist.md C-Auto-1）
- ペネトレーションテスト・DAST はスコープ外として明示する（checklist.md O4）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9 / SKILL.md「重要な制約」）

## 関連ケース

- case-02: スキャン権限なし（SKIPPED 記録）
- case-03: レビュー対象に認証情報パターン（伏字化）
