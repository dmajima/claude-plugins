# チーム選定とエージェント一覧

`extension-reviewer` がレビュー対象に応じて選定するチーム・専門家エージェントの一覧。

## 対象別の採用チーム

| 対象 | 採用するチーム | チーム定義 |
|-----|------------|----------|
| スキル | `skill-review-team`（3 名） | [`../../../teams/skill-review-team.md`](../../../teams/skill-review-team.md) |
| プラグイン | `plugin-review-team`（4〜5 名） | [`../../../teams/plugin-review-team.md`](../../../teams/plugin-review-team.md) |
| フック | `hook-security-team`（3 名） | [`../../../teams/hook-security-team.md`](../../../teams/hook-security-team.md) |
| コマンド | スキルチーム + `description-trigger-reviewer` 単独並列 | [`../../../agents/description-trigger-reviewer.md`](../../../agents/description-trigger-reviewer.md) |
| エージェント / チーム | `description-trigger-reviewer` + `plugin-structure-reviewer` を並列起動（チームを組まない） | 各 agent 定義 |

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
