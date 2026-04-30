# チーム選定とエージェント一覧

`extension-reviewer` がレビュー対象に応じて選定するチーム・専門家エージェントの一覧。

## 対象別の採用チーム

| 対象 | 採用するチーム / 構成 | 定義 |
|-----|------------|----------|
| スキル | `skill-review-team`（3 名、リード含む） | [`../../../references/teams/skill-review-team.md`](../../../references/teams/skill-review-team.md) |
| プラグイン | `plugin-review-team`（フック含有 6 名 / 非含有 5 名、リード含む） | [`../../../references/teams/plugin-review-team.md`](../../../references/teams/plugin-review-team.md) |
| フック | `hook-security-team`（3 名、リード含む） | [`../../../references/teams/hook-security-team.md`](../../../references/teams/hook-security-team.md) |
| コマンド | 専用チームなし、個別 4 名並列（`plugin-structure-reviewer` / `description-trigger-reviewer` / `implementation-engineer` / `security-engineer`、`security-engineer` は外部実行・危険操作を含まない場合省略可で 3 名構成） | [`review-perspectives.md`](review-perspectives.md) セクション 3 |
| エージェント単体定義（`agents/{name}.md`） | 専用チームなし、個別 3 名並列（`plugin-structure-reviewer` / `description-trigger-reviewer` / `architect`） | [evals/case-08](../evals/case-08_agent_definition_review.md) |
| チーム定義（`references/teams/{name}.md`） | 専用チームなし、個別 4 名並列（上記 3 名 + `project-leader`） | [evals/case-09](../evals/case-09_team_definition_review.md) |

## 起動方法

各チーム定義の末尾「スポーンプロンプト」を Agent ツールに渡してメンバーを並列起動:

```text
Agent({ subagent_type: "{lead}", prompt: "（チーム定義のスポーンプロンプト）" })   # 並列
Agent({ subagent_type: "{member-1}", prompt: "..." })                           # 並列
Agent({ subagent_type: "{member-2}", prompt: "..." })                           # 並列
```

各メンバーは独立した観点で評価。メイン Claude が結果を統合する。

## 専門家エージェント一覧

### プラグイン同梱（`plugins/extension-toolkit/agents/`）

| ID | 担当観点 |
|----|---------|
| `plugin-structure-reviewer` | 規約準拠（conventions / ai-readability / readme-policy） |
| `evals-coverage-reviewer` | evals 網羅性 |
| `description-trigger-reviewer` | description のトリガー精度 |
| `marketplace-fit-reviewer` | マーケットプレイス適合 |

### グローバル既存（`~/.claude/agents/`）

| ID | 担当観点 |
|----|---------|
| `architect` | システム構造 |
| `implementation-engineer` | 実装品質 |
| `test-engineer` | テスト網羅 |
| `security-engineer` | セキュリティ |
| `infrastructure-engineer` | インフラ・運用 |
| `project-leader` | 整合性・スコープ |
| `legal-advisor` | 法務・OSS ライセンス（外部公開時） |
| `dba` | データ層（必要時） |
| `ux-designer` | UX（UI を含む場合） |

## チーム未定義の対象への対応

採用チームが未定義の対象の場合、以下を 1 つのメッセージで並列起動する:

- `plugin-structure-reviewer`（プラグイン同梱）
- `description-trigger-reviewer`（プラグイン同梱）
- 対象に応じたグローバル専門家（例: `architect`）

最低 3 名を満たさない場合は適宜追加する。観点が 2 つに固定される対象（例: `gender-perspective` のような 2 視点固定）では 2 名でも可（[`agent-utilization.md`](../../../references/agent-utilization.md) 参照）。

## 機械チェックとの組み合わせ

エージェント並列起動と同時に、機械的チェック（[`automated-checks.md`](automated-checks.md)）を実行する。両者の結果を統合して優先度別に整理する。

## フォールバック起動（チーム機能利用不可時）

`TeamCreate` 機能が利用できない環境では、各チーム定義から **メンバー一覧 + スポーンプロンプト** を抽出し、`Agent` ツールでメンバーを **個別並列起動** する。詳細手順とチーム機能との差分は [`../../../references/agent-utilization.md`](../../../references/agent-utilization.md) の「6.1 チーム機能が利用できない環境でのフォールバック」を参照。

| 起動方式 | 適用条件 | 結果統合 |
|---------|--------|--------|
| チーム機能（`TeamCreate`） | 機能利用可能・議論合意形成が必要 | チーム機能内で自動 |
| 個別並列起動（フォールバック） | チーム機能不可・観点並列レビューで足りる | メイン Claude が手動統合 |

フォールバック使用時はユーザへの最終報告に「チーム機能不可のため Agent 並列起動で代替」と明記する。
