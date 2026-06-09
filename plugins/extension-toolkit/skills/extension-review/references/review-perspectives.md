# レビュー観点とエージェント選定

`extension-review` が対象別に起動するエージェントと、その観点。

## 対象別エージェント選定

### 1. スキルレビュー

| エージェント | 観点 |
|------------|------|
| `implementation-engineer` | SKILL.md の構造妥当性・procedures の論理 |
| `architect` | 責務分離・他スキルとの境界・SSOT 参照 |
| `test-engineer` | evals 充実度・分岐網羅性 |

### 2. プラグインレビュー（横断）

`plugin-review-team` の正典定義は [`../../../references/teams/plugin-review-team.md`](../../../references/teams/plugin-review-team.md) を参照。本セクションは要約。

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `architect`（リード） | グローバル | 全体構造・スキル間の責務分離 |
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（conventions / ai-readability / readme-policy） |
| `implementation-engineer` | グローバル | 各スキル/コマンド/フックの実装品質 |
| `evals-coverage-reviewer` | プラグイン同梱 | evals 全体の網羅性 |
| `marketplace-fit-reviewer` | プラグイン同梱 | マーケットプレイス整合性・命名衝突・依存解決 |
| `security-engineer` | グローバル | フック含有時のみ（フック・外部公開機能の安全性） |

人数: フック含有時 6 名 / 非含有時 5 名。グローバルエージェント不在時のフォールバックは `plugin-review-team.md` を参照。

### 3. コマンドレビュー（専用チームなし、個別エージェント 4 名並列）

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（frontmatter / description 文字数） |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `security-engineer` | グローバル | 実行されるコマンド・スクリプトの危険性 |
| `implementation-engineer` | グローバル | プロンプト構造・ルーティング |

最低 3 名の並列起動を満たす標準構成。コマンドが外部実行・危険操作を含まない場合は `security-engineer` を省略し 3 名構成にしてもよい。

### 4. エージェント単体定義レビュー（個別 3 名並列、専用チームなし）

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（frontmatter / 出力フォーマット定義） |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `architect` | グローバル | 役割の明確性・他エージェントとの差別化 |

詳細は [evals/case-08](../evals/case-08_agent_definition_review.md) を参照。

### 5. チーム定義レビュー（個別 4 名並列、専用チームなし）

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | チーム情報テーブル・スポーンプロンプトの規約準拠 |
| `description-trigger-reviewer` | プラグイン同梱 | チームの起動条件・命名のトリガー精度 |
| `architect` | グローバル | チーム編成の妥当性・観点網羅性 |
| `project-leader` | グローバル | メンバー相補性・サイズ妥当性・議論ラウンド設計 |

エージェント単体定義に対し `project-leader` を追加。詳細は [evals/case-09](../evals/case-09_team_definition_review.md) を参照。

### 6. フックレビュー（セキュリティ重要）

| エージェント | 観点 |
|------------|------|
| `security-engineer`（リード） | command の安全性・終了コード設計 |
| `implementation-engineer` | timeout 設定・パスポータビリティ |
| `infrastructure-engineer` | 副作用・パフォーマンス影響 |

### 7. マーケットプレイスレビュー（個別 3 名並列、専用チームなし）

`marketplace.json` + マーケットプレイス README の整合性レビュー（ADR-019 準拠）。詳細は [evals/case-14_marketplace_review.md](../evals/case-14_marketplace_review.md) を参照。

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `marketplace-fit-reviewer`（リード） | プラグイン同梱 | マーケットプレイス整合・命名衝突・依存解決・README 同期（ADR-019）|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（marketplace README の必須セクション・テーブル形式・追加方法 A+B）|
| `architect` | グローバル | 構造妥当性・拡張性・依存マーケットプレイスの設計 |

`architect` 不在時のフォールバック: `plugin-structure-reviewer` がリード兼任、または `general-purpose` を `architect` の専門性プロンプトで起動（ADR-022 準拠）。

## エージェント起動

### 並列起動の原則

レビュー対象に対し、選定したエージェントを **同一メッセージ内で並列起動** する。各エージェントは独立した観点で評価し、結果はメインで統合する。

### スポーンプロンプトの構造

```text
あなたは {役割名} として以下を評価してください。

対象: {ファイルパス or ディレクトリ}
背景: {対象の目的・公開予定先}

## 評価観点
{役割固有の評価観点（チェックリスト形式）}

## 参照すべき規約
{該当する SSOT ファイル（conventions.md / path-portability.md 等）}

## 出力フォーマット
### Critical / High / Medium / Low / Suggestion
（重大度別の指摘）

### 総合判定
APPROVE / CONDITIONAL_APPROVE / REJECT — {理由 1 行}
```

### 並列起動例

```text
Agent({ subagent_type: "implementation-engineer", prompt: "..." })
Agent({ subagent_type: "architect", prompt: "..." })
Agent({ subagent_type: "security-engineer", prompt: "..." })
```

3 つのツールコールを 1 つのメッセージ内に配置することで並列実行される。

## 観点網羅の原則

最低 3 名のエージェントを起動するが、対象に応じて以下を必ず含める:

| 対象に該当 | 必須エージェント |
|-----------|----------------|
| フックを含む | `security-engineer`（コマンド実行の安全性） |
| 外部公開 API を含む | `security-engineer` + `legal-advisor`（OSS ライセンス・規約） |
| 大規模プラグイン（5 スキル以上） | `project-leader`（整合性） |
| **ユーザ向け UI を含む（後述）** | **`ux-designer`（必須）** |

## ユーザ向け UI 含有の判定基準

`ux-designer` を必須として追加する条件。レビュー対象が以下のいずれかに該当する場合、UI 含有プラグイン・UI 含有スキル・UI 含有コマンドとみなす。

| 区分 | 判定基準 |
|------|---------|
| (a) AskUserQuestion を発火する設計 | SKILL.md / コマンド本文に AskUserQuestion 利用箇所が明記されている |
| (b) 対話的フィードバックを持つ | エラーメッセージ・進捗表示・確認プロンプト（テキスト対話）を含む |
| (c) コマンド引数仕様がある | コマンド frontmatter に `argument-hint` が明記されている |
| (d) ユーザ向け構造化出力 | テーブル / 色付き表示 / プログレスバー等、ユーザ向け視認性が成果物品質に影響する |
| (e) 非対話モードと対話モードの両方を持つ | `--non-interactive` フラグ等で挙動が変わる |

「UI 含有」と判定された場合、`ux-designer` を以下のスコープでチームに追加する。

| 対象 | 追加箇所 |
|------|---------|
| スキルレビュー（節 1） | `ux-designer` を 4 人目として追加（合計 4 名）|
| プラグインレビュー（節 2） | `ux-designer` を追加（フック含有時 7 名 / 非含有時 6 名）|
| コマンドレビュー（節 3） | `ux-designer` を追加（合計 4-5 名）|
| エージェント単体定義（節 4） | 該当なし（エージェント定義は UI を持たないため対象外）|
| チーム定義（節 5） | 該当なし（チーム定義そのものは UI を持たないため対象外）|
| フックレビュー（節 6） | 通常 UI なしのため対象外。ただし PreToolUse hook 等で `additionalContext` でユーザに見える警告を出す場合は追加 |
| マーケットプレイスレビュー（節 7） | 通常 UI なしのため対象外 |

### ux-designer のレビュー観点（必須）

| 観点 | 内容 |
|------|------|
| AskUserQuestion 利用妥当性 | [`../../../references/guides/user-interaction.md`](../../../references/guides/user-interaction.md) / [`askquestion-strategy.md`](../../../references/guides/askquestion-strategy.md) の発火戦略との整合（分岐型 vs 非分岐型 / 利用不可ケースのフォールバック） |
| コマンド引数仕様の妥当性 | [`../../../references/policies/argument-policy.md`](../../../references/policies/argument-policy.md) の「単純な 1 引数」原則 / `argument-hint` 60 文字以内 / フラグ数 |
| エラーメッセージの UX | 原因・対処の明示性 / 専門用語の言い換え / 次にユーザが取るべきアクションの提示 |
| 出力フォーマットの可読性 | 重要情報のハイライト / テーブル列の妥当性 / 大量出力時のサマリー化 |
| アクセシビリティ | 色覚多様性 / コンソール幅対応 / 標準出力と標準エラー出力の使い分け |
| 一貫性 | 既存スキルとの用語統一 / メッセージスタイル統一 |

## 結果統合のルール

各エージェントの指摘を以下のルールで統合:

| ルール | 内容 |
|-------|------|
| 重複指摘の集約 | 同じ問題を複数エージェントが指摘 → 1 件に集約、根拠を併記 |
| 矛盾指摘の提示 | エージェント間で矛盾 → ユーザに提示し判断を仰ぐ |
| 優先度の決定 | 最も高い指摘者の優先度を採用 |

## 総合判定ルール（SSOT）

`extension-review` の総合判定の正典定義。各 evals ケース（case-05 / case-06 / case-10 等）はこの表を参照する。

| 判定 | 条件 |
|-----|------|
| **APPROVE** | Critical 0 + High 0（Medium / Low / Suggestion はあってもよい） |
| **CONDITIONAL_APPROVE** | Critical 0 + High 1 件以上（修正後再レビュー推奨） |
| **REJECT** | Critical 1 件以上 |

注意:
- Medium 件数は判定に直接影響しない。Medium が多数（例: 5 件以上）でも APPROVE は可だが、ユーザに整理して提示する
- Suggestion は判定に影響しない（参考情報）
- 「総合判定」は重大度別の最も厳しい指摘を採用する（例: Critical 1 + High 0 → REJECT）
