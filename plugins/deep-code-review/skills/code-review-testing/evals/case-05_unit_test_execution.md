# case-05 ユニットテストの実行

「ユニットテストを実行して」フレーズで本スキルが起動し、test-runner が実行コマンドを実行（権限なし時は SKIPPED）して pass / fail を報告することを検証するケース。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "ユニットテストを実行して結果を見せて" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

SKILL.md「トリガー条件」の「「ユニットテストを実行して」…と言われた場合」、SKILL.md「動的検証」の「`test-runner` は対応する Bash 権限が許可されている場合のみ実コマンドを実行する」「権限がない・テスト基盤が存在しない・実行不能の場合は SKIPPED として記録する」、SKILL.md「出力フォーマット」（実行ステータス: GREEN | RED | SKIPPED）、references/checklist.md セクション B O3 / セクション C C-Auto-2・C-Auto-3、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U13。

**既存ケースとの差別化**: case-01 / case-02 は委譲経路で test-runner の EXECUTED / SKIPPED を検証し、case-04 は test-engineer のテストコード品質トリガーを主眼とするのに対し、本ケースは「ユニットテストを実行して」の実行依頼フレーズがトリガーになること自体と、test-runner の実行 / SKIPPED 分岐を対話起動で検証する。

## 期待動作

- 起動フレーズ「ユニットテストを実行して結果を見せて」から code-review-testing スキルが起動する（SKILL.md「トリガー条件」）
- test-runner が、対応 Bash 権限（dotnet / npm / jest / vitest / pytest / pwsh 等）があればユニットテスト実行コマンド（`dotnet test` / `npm test` 等）を実行する（SKILL.md「動的検証」）
- 権限がない・テスト基盤が存在しない場合は SKIPPED を理由付きで記録し、「問題なし」「テスト成功」と書き換えない（SKILL.md「動的検証」/ checklist.md C-Auto-2・C-Auto-3 / universal-rules.md U13）
- 実行ステータス（GREEN / RED / SKIPPED）を明示し、RED 時は失敗テストをファイル:メソッド・失敗理由付きで列挙する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-2）
- 実行依頼でも test-engineer も 1 メッセージ内で並列起動する（観点別スキルは全担当エージェントを並列起動する。SKILL.md「実行フロー」手順 2 / checklist.md O1）
- E2E / 結合 / ブラウザ / 性能テストは実行対象外（SKILL.md「E2E・結合テストはスコープ外」/ checklist.md O4）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9）

## 関連ケース

- case-01: 委譲・テスト実行可能（GREEN / RED 報告）
- case-02: テスト基盤なし・権限なし（SKIPPED 記録）
- case-04: テスト品質レビューフレーズでの起動（test-engineer 主眼）
