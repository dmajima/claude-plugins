# case-02 スキャン権限なし（SKIPPED + 静的評価は継続）

脆弱性スキャン用の Bash 権限が許可されていないケース。dependency-safety が動的検証を SKIPPED として理由付きで記録しつつ、静的評価を継続することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard`（依存定義ファイル差分を含む） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | `Bash(dotnet *)` / `Bash(npm *)` / `Bash(pip-audit *)` / `Bash(osv-scanner *)` / `Bash(trivy *)` 等のスキャン権限が未許可 |

## 分岐の根拠

SKILL.md「動的検証」の「権限がない場合は SKIPPED として記録する」、SKILL.md「前提」の観点表（dependency-safety の責務は依存関係・破壊的変更・マイグレーション・設定階層整合 + 脆弱性スキャン実行可。動的なのは脆弱性スキャンのみ）、references/checklist.md セクション B O3 およびセクション C C-Auto-2（動的検証ステータス EXECUTED/SKIPPED の明示）/ C-Auto-3（SKIPPED 時の理由併記）、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13（「未実施」を「問題なし」と書き換えない）。

## 期待動作

- security-engineer / dependency-safety の 1 メッセージ内並列起動は通常通り行う（references/checklist.md O1）
- dependency-safety は脆弱性スキャンを実コマンド実行せず、中間レポートに「動的検証: SKIPPED（権限なし）」のように理由を併記して記録する（SKILL.md「動的検証」/ checklist.md O3 / C-Auto-3）
- SKIPPED を「脆弱性なし」「問題なし」と書き換えない（universal-rules.md U13）
- 依存関係・破壊的変更・マイグレーション・設定階層整合の静的評価は SKIPPED でも実施して報告する（SKILL.md「前提」の観点表）
- security-engineer の OWASP / STRIDE 観点レビューは通常通り実施する（SKILL.md「前提」の観点表）
- 「### dependency-safety」セクションは省略せず、必須セクションを揃えた中間レポートを返却する（checklist.md C-Auto-1 / O2）

## 関連ケース

- case-01: スキャン権限あり（EXECUTED 記録）
