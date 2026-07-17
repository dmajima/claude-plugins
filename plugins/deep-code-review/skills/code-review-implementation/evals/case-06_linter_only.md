# case-06 Linter / 静的解析のみ実行

「Linter だけ実行して」フレーズで本スキルが起動し、linter-static-analysis が動的検証を実行（権限なし時は SKIPPED 記録）することを検証するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "Linter だけ実行して静的解析の結果を見せて" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「Linter / 静的解析だけ実行して」と言われた場合」、SKILL.md「動的検証」の「`linter-static-analysis` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する」「権限がない場合は SKIPPED として記録（「未実施」を「問題なし」と書かない）」、references/checklist.md セクション B O3 / セクション C C-Auto-2、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13。

**既存ケースとの差別化**: case-03 は「実装品質をレビューして」の総合フレーズによる単独実行で SKIPPED + progress.md を扱うのに対し、本ケースは Linter 単体依頼フレーズがトリガーになること自体と、linter-static-analysis の EXECUTED / SKIPPED 分岐を検証する。Linter 重点依頼でも観点別スキルの規約（O1）により 3 エージェントの並列起動自体は維持される。

## 期待動作

- 起動フレーズ「Linter だけ実行して静的解析の結果を見せて」から code-review-implementation スキルが起動する（SKILL.md「トリガー条件」）
- linter-static-analysis は、対応する Bash 権限（dotnet / npm / eslint / prettier / tsc / pwsh / ruff 等）が許可されていれば動的検証コマンドを実行し、中間レポートに「動的検証: EXECUTED」と記録する（SKILL.md「動的検証」）
- 権限がない場合は実コマンドを実行せず「動的検証: SKIPPED（理由）」として記録し、「未実施」を「問題なし」「指摘なし」と書き換えない（SKILL.md「動的検証」/ checklist.md C-Auto-2 / universal-rules.md U13）
- linter-static-analysis が検出した規約・整形・型違反を「### linter-static-analysis」セクションに記載する（SKILL.md「出力フォーマット」）
- Linter 重点依頼でも観点別スキルの規約に従い implementation-engineer / performance-reviewer も含めて 1 メッセージ内で並列起動する（SKILL.md「実行フロー」手順 2 / checklist.md O1）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-01: 委譲・動的検証権限あり（EXECUTED 記録）
- case-03: 単独実行・動的検証権限なし（SKIPPED 記録・progress.md 自スキル作成）
- case-04: 実装正確性を含む総合トリガー（3 観点評価）
