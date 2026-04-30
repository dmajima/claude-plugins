# レビュー観点とエージェント選定

`extension-reviewer` が対象別に起動するエージェントと、その観点。

## 対象別エージェント選定

### 1. スキルレビュー

| エージェント | 観点 |
|------------|------|
| `implementation-engineer` | SKILL.md の構造妥当性・procedures の論理 |
| `architect` | 責務分離・他スキルとの境界・SSOT 参照 |
| `test-engineer` | evals 充実度・分岐網羅性 |

### 2. プラグインレビュー（横断）

| エージェント | 観点 |
|------------|------|
| `architect`（リード） | 全体構造・スキル間の責務分離 |
| `implementation-engineer` | 各スキル/コマンド/フックの実装品質 |
| `security-engineer` | フック・外部公開機能の安全性 |
| `test-engineer` | evals 全体の網羅性 |
| `project-leader` | マーケットプレイス整合性・命名衝突 |

### 3. コマンドレビュー（専用チームなし、個別エージェント 4 名並列）

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（frontmatter / description 文字数） |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `security-engineer` | グローバル | 実行されるコマンド・スクリプトの危険性 |
| `implementation-engineer` | グローバル | プロンプト構造・ルーティング |

最低 3 名の並列起動を満たす標準構成。コマンドが外部実行・危険操作を含まない場合は `security-engineer` を省略し 3 名構成にしてもよい。

### 4. エージェント単体レビュー

| エージェント | 観点 |
|------------|------|
| `architect` | 役割の明確性・他エージェントとの差別化 |
| `implementation-engineer` | 評価観点の具体性・出力フォーマット |
| `project-leader` | 既存エージェント体系との整合 |

### 5. チームレビュー

| エージェント | 観点 |
|------------|------|
| `architect`（リード） | 観点網羅性・サイズ妥当性 |
| `project-leader` | リード選定・議論ラウンド設計 |
| `implementation-engineer` | スポーンプロンプトの実装可能性 |

### 6. フックレビュー（セキュリティ重要）

| エージェント | 観点 |
|------------|------|
| `security-engineer`（リード） | command の安全性・終了コード設計 |
| `implementation-engineer` | timeout 設定・パスポータビリティ |
| `infrastructure-engineer` | 副作用・パフォーマンス影響 |

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
| ユーザ操作を伴う | `ux-designer`（あれば） |

## 結果統合のルール

各エージェントの指摘を以下のルールで統合:

| ルール | 内容 |
|-------|------|
| 重複指摘の集約 | 同じ問題を複数エージェントが指摘 → 1 件に集約、根拠を併記 |
| 矛盾指摘の提示 | エージェント間で矛盾 → ユーザに提示し判断を仰ぐ |
| 優先度の決定 | 最も高い指摘者の優先度を採用 |
| 総合判定 | 1 名でも REJECT → CONDITIONAL_APPROVE 以下、Critical なし → APPROVE |
