# チーム定義チェックリスト

`references/teams/{name}.md` を対象とするチェック項目。`common.md` の項目と併用すること。

## T-1. ファイル名・配置

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-1-1 | High | ファイル名が kebab-case + `.md`（例: `skill-review-team.md`） | [conventions.md](../../../references/conventions.md) 節 1 |
| T-1-2 | High | 配置が `plugins/{plugin}/references/teams/{name}.md`（プラグイン直下 `teams/` への配置は禁止・ADR-002） | 同 節 2.3 |

## T-2. チーム情報テーブル

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-2-1 | High | 「チーム情報」テーブルが存在し、`目的 / リード / メンバー（リード以外）/ 人数 / 議論ラウンド` を含む | 既存チーム定義（`skill-review-team.md` / `plugin-review-team.md` / `hook-security-team.md`）の構成 |
| T-2-2 | High | リードエージェントが指定されている | [validation-rules.md](../../../references/validation-rules.md) 節 2.5 |
| T-2-3 | High | メンバー数が 3 名以上（観点が 2 つに固定の場合は 2 名でも可、その理由をチーム定義に明記） | [agent-utilization.md](../../../references/agent-utilization.md) 節 6 |
| T-2-4 | Medium | メンバー数の上限を超えていない（標準 5 名、`plugin-review-team` のフック含有時のみ 6 名まで許容） | 同上 |

## T-3. 議論ラウンド

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-3-1 | Medium | 議論ラウンド数が「最低 3、上限 5」の範囲で指定されている | [validation-rules.md](../../../references/validation-rules.md) 節 2.5 |

## T-4. メンバー構成と専門性

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-4-1 | High | 各メンバーの「ID / 配布元（プラグイン同梱 or グローバル）/ 役割 / 専門性 / 主な評価軸」が表形式で記載されている | 既存チーム定義の構成 |
| T-4-2 | High | 各メンバーのエージェント定義が実在する（`agents/{name}.md` または `~/.claude/agents/{name}.md`） | [validation-rules.md](../../../references/validation-rules.md) 節 2.5 |
| T-4-3 | Medium | メンバー間で専門性が相補的（重複なし） | 同上 |

## T-5. グローバルエージェント不在時のフォールバック（ADR-022）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-5-1 | High | グローバルエージェント（`architect` / `implementation-engineer` / `security-engineer` 等）に依存する場合、不在時のフォールバックが明示されている | [self-containment.md](../../../references/self-containment.md) 節 2.2 |
| T-5-2 | High | フォールバック先がプラグイン同梱版 or `general-purpose` を専門性プロンプトで起動 | [plugin-review-team.md](../../../references/teams/plugin-review-team.md) / [hook-security-team.md](../../../references/teams/hook-security-team.md) |

## T-6. スポーンプロンプト（ADR-021 準拠）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-6-1 | High | 必須引き継ぎ事項（目的 / 担当役割 / ユーザー指摘 / 対象 / 観点 / 出力フォーマット）が含まれる | [review-freshness.md](../../../references/review-freshness.md) 節 2 |
| T-6-2 | High | 引き継ぎ禁止事項（過去レビュー結論・「修正済み」「対応完了」等のメタ評価・重大度予断）がスポーンプロンプトに含まれていない | 同 節 3 |
| T-6-3 | High | スポーンプロンプト末尾に「過去の議論・修正履歴・他レビュアーの結論は与えていません」等の注記がある | 既存チーム定義の構成 |

## T-7. 調整ガイドライン

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-7-1 | Medium | リードが論点を提示し、メンバーが反論・補強する役割分担が明示されている | 既存チーム定義の構成 |
| T-7-2 | Medium | 合意に至らない項目はトレードオフを明示してユーザに判断を仰ぐ運用が示されている | 同上 |

## T-8. 重複・差別化

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-8-1 | Medium | 既存チーム（`plugin-review-team` / `skill-review-team` / `hook-security-team` 等）と役割が重複していない、または差別化点が明示されている | [agent-utilization.md](../../../references/agent-utilization.md) 節 5.3 |

## T-9. レビューエージェント並列起動（チーム定義レビュー時）

| 項目 | 重大度 | 確認方法 | 出典 |
|-----|-------|---------|-----|
| T-9-1 | High | 専用チームなし、個別 4 名（`plugin-structure-reviewer` / `description-trigger-reviewer` / `architect` / `project-leader`）並列起動された | [review-perspectives.md](../review-perspectives.md) 節 5 / [team-selection.md](../team-selection.md) |
