# レビュー手順自体の自己点検チェックリスト

`extension-review` がレビュー結果を報告する直前に、**レビュー手順そのもの** が SSOT に従って実施されたかを自己点検するチェック項目。`common.md` の項目と併用すること。

## PR-1. 対象判定の正確性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-1-1 | Critical | レビュー対象の種別（スキル / プラグイン / マーケットプレイス / コマンド / エージェント / チーム / フック / README）を SKILL.md 節「1. 対象判定」のテーブルに従って正しく判定した | [SKILL.md](../../SKILL.md) 節 1 |
| PR-1-2 | High | 複数種別が混在する対象（プラグイン全体）に対し、含有要素ごとのチェックリストもすべて適用した | [SKILL.md](../../SKILL.md) 節 1 / [README.md](README.md) 節 2 |

## PR-2. レビュー観点の選定

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-2-1 | High | [`review-perspectives.md`](../review-perspectives.md) の対象別エージェント選定テーブルに従って観点を選定した | [SKILL.md](../../SKILL.md) 節 2 |
| PR-2-2 | High | 観点網羅の原則（フック含有時の `security-engineer` 必須等）を満たしている | [review-perspectives.md](../review-perspectives.md) 節「観点網羅の原則」 |

## PR-3. チームの起動 / 並列起動

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-3-1 | High | [`team-selection.md`](../team-selection.md) の対象別チーム表に従ってチームを起動した（または同等構成を Agent 並列起動した） | [SKILL.md](../../SKILL.md) 節 3 / [team-selection.md](../team-selection.md) |
| PR-3-2 | High | TeamCreate 利用不可の場合、`Agent` ツールでメンバーを **同一メッセージ内で並列起動** している | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 6.1 |
| PR-3-3 | High | 最低 3 名のエージェントが並列起動された（観点 2 つに固定の場合は 2 名でも可、理由必須） | [validation-rules.md](../../../references/checklists/validation-rules.md) 節 2.5 |
| PR-3-4 | High | `description-trigger-reviewer` が必要対象（スキル / コマンド / エージェント / チーム）でチーム外の単独並列起動として呼ばれている | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 5.4 |
| PR-3-5 | High | フォールバック起動時、ユーザへの最終報告に「チーム機能不可のため Agent 並列起動で代替」が明記される予定である | 同 節 6.1.5 |

## PR-4. レビューフレッシュ起動原則（ADR-021）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-4-1 | High | 各エージェントのスポーンプロンプトに必須引き継ぎ事項（目的 / 役割 / ユーザー指摘 / 対象 / 観点 / 出力フォーマット）が明記されている | [review-freshness.md](../../../references/checklists/review-freshness.md) 節 2 |
| PR-4-2 | High | スポーンプロンプトに引き継ぎ禁止事項（過去レビュー結論 / 「修正済み」「対応完了」/ 重大度予断）が含まれていない | 同 節 3 |
| PR-4-3 | High | 修正実装と同一インスタンスでレビューを行っていない（フレッシュインスタンスで起動した） | 同 節 5 |
| PR-4-4 | Medium | スポーンプロンプト末尾に「過去の議論・修正履歴・他レビュアーの結論は与えていません」等の注記が含まれる | 既存チーム定義の構成 |

## PR-5. 機械チェック（`run_checks.py`）の実施

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-5-1 | Critical | `run_checks.py` を **Bash 経由 + venv 内 Python + JSON ファイル出力** で実行した（PowerShell 直接起動禁止） | [automated-checks.md](../automated-checks.md) |
| PR-5-2 | High | `--target` `--scope-root` `--output` 引数を適切に指定した | 同上 |
| PR-5-3 | High | 実行結果 JSON ファイルを Read で読み取り、`issues` 配列を統合した | 同上 |
| PR-5-4 | High | 失敗（exit != 0）時は stderr の `[ERROR]` 行を `progress.md` の「ブロッカー・懸念事項」節に転記した | 同上 |
| PR-5-5 | High | venv 構築・撤去はプラグイン直下 `references/scripts/setup/` のスクリプトに委譲した（ADR-024） | [scripts-policy.md](../../../references/policies/scripts-policy.md) 節 5.4 |

## PR-6. 結果統合

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-6-1 | High | エージェント並列レビュー結果と機械チェック結果を統合した | [SKILL.md](../../SKILL.md) 節 5 |
| PR-6-2 | High | 重複指摘を 1 件に集約し、根拠（指摘エージェント名）を併記した | [review-perspectives.md](../review-perspectives.md) 節「結果統合のルール」 |
| PR-6-3 | High | エージェント間で矛盾する指摘がある場合、ユーザに提示し判断を仰ぐ運用にした | 同上 |
| PR-6-4 | High | 各指摘に重大度（Critical / High / Medium / Low）と該当ファイルパス（行番号付き）を記載した | 同上 |

## PR-7. 総合判定

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-7-1 | Critical | 総合判定が `APPROVE` / `CONDITIONAL_APPROVE` / `REJECT` のいずれかで明示されている | [review-perspectives.md](../review-perspectives.md) 節「総合判定ルール」 |
| PR-7-2 | Critical | 判定ルール（Critical 1 件以上 → `REJECT`、Critical 0 + High 1 件以上 → `CONDITIONAL_APPROVE`、Critical 0 + High 0 → `APPROVE`）に従っている | 同上 |
| PR-7-3 | High | Critical / High 指摘が修正されない限り `APPROVE` を確定していない | 同上 |

## PR-8. 自動修正の境界

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-8-1 | High | `--auto-fix` モードでも、構造的問題・description 不適切・セキュリティ指摘は自動修正していない | [SKILL.md](../../SKILL.md) 節 6 |
| PR-8-2 | Critical | セキュリティ指摘（Critical / High）は必ずユーザ確認を経ている | 同上 |
| PR-8-3 | Medium | 自動修正の対象（パスポータビリティ・プレースホルダ・フォーマット）以外を勝手に修正していない | 同上 |

## PR-9. 引き渡し（次工程の案内）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-9-1 | Medium | Critical / High なし → `marketplace-publish` への接続を提案している | [SKILL.md](../../SKILL.md) 節 7 |
| PR-9-2 | Medium | Critical / High あり → 該当 `*-toolkit` への接続を提案し、修正後再レビューを推奨している | 同上 |

## PR-10. 報告フォーマット

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-10-1 | High | 報告に「## レビュー結果統合」セクションがあり、Critical / High / Medium / Low / Suggestion の重大度別に整理されている | [SKILL.md](../../SKILL.md) 節 5 |
| PR-10-2 | High | 各指摘にファイルパス + 行番号 + 担当エージェント名 + 具体的な問題と修正案を記載している | [review-perspectives.md](../review-perspectives.md) |
| PR-10-3 | High | 報告に「## チェックリスト通過記録」セクションが含まれ、適用ファイル・項目数・OK/NG/未確認の集計が示されている | [README.md](README.md) 節 5 |
| PR-10-4 | Medium | フォールバック起動時はその旨をユーザへの最終報告に明記している | [agent-utilization.md](../../../references/guides/agent-utilization.md) 節 6.1.5 |

## PR-11. 進捗管理（progress.md）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-11-1 | Medium | 3 タスク以上 / マルチエージェント作業の場合、`progress.md` を作成・更新している | グローバルルール `~/.claude/rules/claude/progress-management.md`（参照は任意・利用者環境に依存しないようプラグインのルール集約優先） |
| PR-11-2 | Medium | 機械チェックの stderr 警告を `progress.md` の「ブロッカー・懸念事項」節に転記している | [automated-checks.md](../automated-checks.md) |

## PR-12. 完了前自己検証

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-12-1 | High | [`completion-checklist.md`](../../../references/checklists/completion-checklist.md) の 3 軸（ルール順守 / 要件適合 / 結果完全性）を実施した | [completion-checklist.md](../../../references/checklists/completion-checklist.md) |
| PR-12-2 | High | 結果サマリ（チェック結果・要件適合性・結果完全性）を報告に含めている | 同 節 4 |

## PR-13. チェックリスト全体の通過確認

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| PR-13-1 | Critical | 本ディレクトリ（`checklists/`）配下の **適用ファイル全項目を走査** した（未確認項目はゼロ、または明示的な NA 判定 + 理由を記録） | [README.md](README.md) 節 1 / 4 |
| PR-13-2 | Critical | High 以上の未確認項目がある場合、総合判定を `CONDITIONAL_APPROVE` 以下に抑え、未確認理由をレポートに明記した | [README.md](README.md) 節 1 |
