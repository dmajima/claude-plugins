# Case 08: エージェント定義レビュー（個別 3 名並列）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-quality-reviewer` エージェント定義をレビュー" |
| 引数 | `agents/{name}.md` |
| フラグ | なし |
| 既存状態 | エージェント定義が単体ファイル |

## 期待動作

### Phase 1: 対象判定

`agents/{name}.md`（frontmatter `name` を識別）→ エージェント定義レビューモード。

### Phase 2: 個別エージェント選定（3 名）

[`../references/team-selection.md`](../references/team-selection.md) に従う。専用チームを設けず、以下を並列起動:

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（frontmatter 必須・出力フォーマット定義） |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `architect` | グローバル | 役割の明確性・他エージェントとの差別化 |

### Phase 3: 並列起動 + 機械チェック

| 機械チェック | 内容 |
|------------|------|
| frontmatter | `name` `description` `model` `tools` の存在 |
| 評価観点 | 3 つ以上の項目があるか |
| 出力フォーマット | 定義済みか（Critical / High / Medium / Low / 総合判定） |
| プロンプトテンプレート | 存在するか |

### Phase 4: 結果統合 + 引き渡し

通常の統合 → 優先度付け → 次アクション提案（修正は `agent-toolkit` で）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | エージェント別の指摘 + 統合レビュー結果 + 総合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = エージェント単体定義（`agents/{name}.md`）。専用チームなし、個別エージェント 3 名の並列起動。

## 関連ケース

- `case-01_skill_review.md`（スキル単体）
- `case-07_command_review.md`（コマンド単体、同様に専用チームなし）
- `case-09_team_definition_review.md`（チーム定義レビュー、4 名構成）
