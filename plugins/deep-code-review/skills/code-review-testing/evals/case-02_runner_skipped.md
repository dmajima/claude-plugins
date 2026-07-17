# case-02 テスト実行不能（SKIPPED + 理由併記）

ユニットテスト基盤が存在しない、または実行権限が許可されていないケース。test-runner が実行ステータス SKIPPED を理由付きで記録し、「問題なし」へ書き換えないことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 前提 | テスト基盤が存在しない、または `Bash(dotnet *)` / `Bash(npm *)` 等の実行権限が未許可 |

## 分岐の根拠

SKILL.md「動的検証」の「権限がない・テスト基盤が存在しない・実行不能の場合は SKIPPED として記録する」、references/checklist.md セクション B O3 およびセクション C C-Auto-2（実行ステータス GREEN/RED/SKIPPED の明示）/ C-Auto-3（SKIPPED 時の理由併記）、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13（「未実施」を「問題なし」と書き換えない / SKIPPED 理由の明記）。

## 期待動作

- test-engineer / test-runner の 1 メッセージ内並列起動自体は通常通り行う（references/checklist.md O1）
- test-runner は実コマンドを実行せず、中間レポートに「実行ステータス: SKIPPED（テスト基盤なし）」「実行ステータス: SKIPPED（権限なし）」のように実際の原因を理由として併記する（SKILL.md「動的検証」/ checklist.md C-Auto-3 / universal-rules.md U13）
- SKIPPED を「テスト成功」「問題なし」と書き換えない（universal-rules.md U13）
- test-engineer によるテストコード品質の静的レビュー（網羅性・エッジケース・モック過剰等）は通常通り実施し報告する（SKILL.md「前提」の観点表）
- 「### test-runner」セクションは省略せず、必須セクションを揃えた中間レポートを返却する（checklist.md C-Auto-1 / O2）
- SKIPPED の理由は権限なし・コマンド未導入・基盤なし等の実際の原因を記載する（universal-rules.md U13 達成基準）

## 関連ケース

- case-01: テスト実行可能（GREEN / RED 報告）
