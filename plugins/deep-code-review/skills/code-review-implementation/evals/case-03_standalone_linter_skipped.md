# case-03 単独実行・動的検証権限なし（SKIPPED 明示）

ユーザーが本スキルを直接起動し、かつ Linter / ビルド系の動的検証用 Bash 権限が許可されていないケース。SKIPPED の理由付き記録と、オーケストレーター不在時の progress.md 自スキル作成を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "実装品質をレビューして" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 前提 | 動的検証用権限（`Bash(dotnet *)` / `Bash(npm *)` / `Bash(eslint *)` 等）が未許可 |

## 分岐の根拠

SKILL.md「トリガー条件」の「「実装品質をレビューして」…と言われた場合」、SKILL.md「動的検証」の「権限がない場合は SKIPPED として記録（「未実施」を「問題なし」と書かない）」、references/checklist.md セクション B O3 / O8、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13（動的検証の SKIPPED 明示・「未実施」を「問題なし」と書き換えない。SSOT。checklist.md セクション C C-Auto-2 が自動確認を担う）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4（オーケストレーター不在時は本スキル自身で progress.md を作成・維持）。

## 期待動作

- トリガーフレーズ「実装品質をレビューして」から本スキルが単独起動する（SKILL.md「トリガー条件」）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8 / common-references.md セクション 4）
- 3 エージェント（implementation-engineer / linter-static-analysis / performance-reviewer）の 1 メッセージ内並列起動は通常通り行う（checklist.md O1）
- linter-static-analysis は実コマンドを実行せず、中間レポートに「動的検証: SKIPPED（権限なし）」のように理由を併記して記録する（SKILL.md「動的検証」/ checklist.md O3 / universal-rules.md U13）
- SKIPPED を「問題なし」「指摘なし」と書き換えない（SKILL.md「動的検証」/ universal-rules.md U13。checklist.md C-Auto-2 で自動確認）
- 動的検証が SKIPPED でも「### linter-static-analysis」セクション自体は省略せず、必須セクションを揃えた中間レポートを返却する（checklist.md C-Auto-1）
- 中間レポートの構造は委譲時と同一の「出力フォーマット」に従う（checklist.md O2）

## 関連ケース

- case-01: 委譲・動的検証権限あり（EXECUTED 記録）
