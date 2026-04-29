# Case 01: スキルレビュー（skill-review-team 起動）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルをレビュー" |
| 引数 | `code-formatter` |
| フラグ | なし |
| 既存状態 | スキルが存在 |

## 期待動作

### Phase 1: 対象判定

`SKILL.md` 含むディレクトリを検出 → スキルレビューモード。

### Phase 2: チーム選定

[`../references/team-selection.md`](../references/team-selection.md) に従い `skill-review-team`（3 名）を採用。

| メンバー | 配布元 | 役割 |
|--------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | リード（規約準拠） |
| `implementation-engineer` | グローバル | 実装品質 |
| `evals-coverage-reviewer` | プラグイン同梱 | evals 網羅性 |

### Phase 3: チーム起動 + 機械チェック

[`../../../teams/skill-review-team.md`](../../../teams/skill-review-team.md) のスポーンプロンプトに従い、3 名を 1 メッセージ内で **並列 Agent 起動**。同時に機械チェック（[`automated-checks.md`](automated-checks.md)）を実行。

### Phase 4: 結果統合

各メンバー結果と機械チェック結果を統合し、優先度別に整理。

### Phase 5: 引き渡し

| 結果 | 接続先 |
|-----|-------|
| Critical/High なし | `marketplace-publisher` への接続を提案 |
| Critical/High あり | 該当 `*-toolkit` への接続を提案 |

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | チーム起動結果（メンバー別の指摘）+ 統合レビュー結果（Critical / High / Medium / Low / 総合判定）+ 次のアクション提案 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = スキル → `skill-review-team` 採用。

## 関連ケース

- `case-02_plugin_review.md`（プラグイン横断、`plugin-review-team`）
- `case-03_hook_review.md`（フック専用、`hook-security-team`）
- `case-07_command_review.md`（コマンド単体、スキルチーム + `description-trigger-reviewer`）
- `case-08_agent_team_review.md`（エージェント / チーム定義レビュー）
