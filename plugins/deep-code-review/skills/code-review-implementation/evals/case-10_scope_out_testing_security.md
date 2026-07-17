# case-10 スコープ外観点の他スキル誘導（O4/O5: テスト実行 / セキュリティ要求の混在）

実装品質レビュー依頼に、テスト実行（ユニット/E2E の実行）とセキュリティ観点（脆弱性・認証設計）の要求が混在するケース。実装品質観点はスコープ内で評価しつつ、テスト実行を `code-review-testing`、セキュリティを `code-review-security` へ誘導し、各指摘にスコープ内/外フラグを付与する O4/O5 分岐を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この実装の品質をレビューして。ついでにユニットテストと E2E テストも実行して、認証まわりの脆弱性も突いてみて" |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` O4（自スキルのスコープ外は対応スキルへ誘導）/ O5（指摘・改善提案にスコープ内/外フラグを付与して返却）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 5「スコープ外振分けルール」（`code-review-implementation`: テスト → `code-review-testing` / セキュリティ → `code-review-security`）、references/checklist.md セクション B の O4 / O5、SKILL.md「責務」（実装品質観点＝実装正確性・コーディング規約・パフォーマンスの 3 観点に分解）・「動的検証」（`linter-static-analysis` はビルド/Linter 実行であり、テスト実行〈test-runner〉は担当外）、`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` U7 / U8（PR 外への影響禁止・別 PR 推奨の禁止）。

> **差別化**: 本ケースは O4/O5 の **スコープ外誘導とスコープ内/外フラグ付与** を主眼とする。同種の実装品質トリガーを扱う case-04 は 3 エージェント並列起動と 3 観点評価の成立自体を検証する（スコープ外誘導は扱わない）。観点別 5 スキル共通の O4 誘導ケースとして code-review-testing/case-03（testing→対象外）・code-review-security/case-07（security→動的テスト対象外）と対をなす。

## 期待動作

- 実装品質観点（実装正確性・コーディング規約・パフォーマンス）は **スコープ内** として implementation-engineer / linter-static-analysis / performance-reviewer の 3 エージェント並列起動で評価する（SKILL.md「責務」/ checklist.md O1）
- テスト実行（ユニット/E2E の実行・テスト十分性の評価）は本スキルのスコープ外とし、`code-review-testing` へ誘導する（O4 / common-references.md セクション 5）
- セキュリティ観点（認証設計の脆弱性・攻撃面分析）は本スキルのスコープ外とし、`code-review-security` へ誘導する（O4 / common-references.md セクション 5）
- `linter-static-analysis` の動的検証はビルド/Linter コマンドに限られ、テスト実行（test-runner）は行わない。テスト実行要求は誘導先で扱う旨を明示する（SKILL.md「動的検証」）
- 各指摘・改善提案に「スコープ内 / スコープ外」フラグを付与して返却する（O5 / checklist.md セクション B O5）
- スコープ外と判断した観点は「別 PR で対応してください」「別チケット化してください」「Issue を作成」等の禁止文言を使わず、スコープ外フラグ + 誘導先スキル名で返却する（U7 / U8 / checklist.md セクション C の C-Auto-3 禁止文言検査）
- 実際の攻撃コードの実行・生成は行わず、指摘・推奨対応の提示にとどめる（SKILL.md「重要な制約」）
- Finding ID（CR-NNN）の採番・Verdict 判定・統合サマリ生成は行わない（checklist.md O9。オーケストレーター責務）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（O8 / common-references.md セクション 4）

## 関連ケース

- case-04: 実装品質トリガーでの 3 エージェント並列起動・3 観点評価（スコープ外誘導を扱わない対比）
- code-review-testing/case-03: testing スキルの O4 スコープ外誘導（E2E → 対象外）
- code-review-security/case-07: security スキルの O4 スコープ外誘導（DAST/ペネトレーションテスト → 対象外）
