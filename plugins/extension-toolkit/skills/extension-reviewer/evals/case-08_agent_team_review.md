# Case 08: エージェント / チーム定義レビュー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-quality-reviewer` エージェント定義をレビュー" or "`skill-review-team` チーム定義をレビュー" |
| 引数 | `agents/{name}.md` または `teams/{name}.md` |
| フラグ | なし |
| 既存状態 | エージェント / チーム定義が単体ファイル |

## 期待動作

### Phase 1: 対象判定

| 検出 | 判定 |
|-----|------|
| `agents/{name}.md`（frontmatter `name` を識別） | エージェント定義レビュー |
| `teams/{name}.md` | チーム定義レビュー |

### Phase 2: エージェント並列選定

[`../references/team-selection.md`](../references/team-selection.md) に従う。専用チームを設けず、以下を並列起動:

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠（frontmatter 必須・出力フォーマット定義） |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `architect` | グローバル | 役割の明確性・他エージェントとの差別化 |

最低 3 名を並列起動。チーム定義レビューの場合は `project-leader`（メンバー相補性・サイズ妥当性）を加えて 4 名構成とする。

### Phase 3: 並列起動 + 機械チェック

| 機械チェック | 内容 |
|------------|------|
| frontmatter | `name` `description` `model` `tools` の存在 |
| 評価観点 | 3 つ以上の項目があるか |
| 出力フォーマット | 定義済みか |
| 必須要素（チーム） | リード指定・メンバー数（最低 3 名 or 観点固定で 2 名）・議論ラウンド数（最低 3） |

### Phase 4: 結果統合 + 引き渡し

通常の統合 → 優先度付け → 次アクション提案（修正は `agent-toolkit` で）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | エージェント別の指摘 + 統合レビュー結果 + 総合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = エージェント or チーム定義（専用チームなし、個別エージェントの並列起動）。

## 関連ケース

- `case-01_skill_review.md`（スキル単体）
- `case-07_command_review.md`（コマンド単体、同様に専用チームなし）
