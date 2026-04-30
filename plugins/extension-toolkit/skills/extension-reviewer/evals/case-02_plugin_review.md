# Case 02: プラグイン全体レビュー（plugin-review-team 起動）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`extension-toolkit` プラグイン全体をレビュー" |
| 引数 | `extension-toolkit` |
| フラグ | なし |
| 既存状態 | プラグイン全体が存在（フック含む） |

## 期待動作

### Phase 1: 対象判定

`.claude-plugin/plugin.json` 含むディレクトリ → プラグインレビューモード。フック有無を検出（`hooks/hooks.json` の存在）。

### Phase 2: チーム選定

[`../references/team-selection.md`](../references/team-selection.md) に従い `plugin-review-team` を採用。フック含有のため `security-engineer` を含む **6 名構成**（リード含む）。

| メンバー | 配布元 | 役割 |
|--------|-------|------|
| `architect` | グローバル | リード（全体構造） |
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠 |
| `implementation-engineer` | グローバル | 実装品質 |
| `evals-coverage-reviewer` | プラグイン同梱 | evals 網羅性 |
| `marketplace-fit-reviewer` | プラグイン同梱 | マーケット適合 |
| `security-engineer` | グローバル | フック安全性（フック含有時） |

フック未含有なら `security-engineer` を省略し **5 名構成**（リード含む）になる。

**グローバルエージェント不在時のフォールバック**: `architect` / `implementation-engineer` / `security-engineer` が利用者環境に存在しない場合は [`../../../references/teams/plugin-review-team.md`](../../../references/teams/plugin-review-team.md) の「グローバルエージェント不在時のフォールバック」節に従い同梱版または `general-purpose` で代替（ADR-022 準拠）。

### Phase 3: チーム起動 + 機械チェック（フレッシュ起動・ADR-021 準拠）

[`../../../references/teams/plugin-review-team.md`](../../../references/teams/plugin-review-team.md) のスポーンプロンプトに従い、**フレッシュ Agent インスタンス**（過去議論・修正履歴・他レビュアー結論を引き継がない）でメンバーを 1 メッセージ内で **並列 Agent 起動**。詳細は [`../../../references/review-freshness.md`](../../../references/review-freshness.md) を参照。各スキル/コマンド/フックを横断的に機械チェック。

### Phase 4: 結果統合

スキル毎・要素毎にグルーピングして整理。

### Phase 5: 引き渡し

総合判定に応じて次のアクションを提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | スキル毎にグルーピングされた統合レビュー結果（メンバー別所見 + 統合判定） |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = プラグイン → `plugin-review-team` 採用。

## 関連ケース

- `case-01_skill_review.md`（スキル単体）
- `case-03_hook_review.md`（フック専用）
