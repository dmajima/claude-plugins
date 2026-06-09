# Case 13: プラグイン全体レビュー（フック未含有・5 名構成）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`pure-skill-toolkit` プラグイン全体をレビュー" |
| 引数 | `pure-skill-toolkit` |
| フラグ | なし |
| 既存状態 | プラグイン全体が存在、**フック非含有**（`hooks/` ディレクトリなし、`hooks.json` なし） |

## 期待動作

### Phase 1: 対象判定 + フック有無検出

`.claude-plugin/plugin.json` 含むディレクトリ → プラグインレビューモード。
`hooks/hooks.json` の存在チェック → **未存在を確認** → フック非含有プラグインとして判定。

### Phase 2: チーム選定（5 名構成）

[`../references/team-selection.md`](../references/team-selection.md) に従い `plugin-review-team` を採用。
**フック未含有のため `security-engineer` を起動しない 5 名構成** となる。

| メンバー | 配布元 | 役割 |
|--------|-------|------|
| `architect` | グローバル | リード（全体構造） |
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠 |
| `implementation-engineer` | グローバル | 実装品質 |
| `evals-coverage-reviewer` | プラグイン同梱 | evals 網羅性 |
| `marketplace-fit-reviewer` | プラグイン同梱 | マーケット適合 |

### Phase 3: チーム起動 + 機械チェック

`security-engineer` を起動しない 5 名のスポーンプロンプトを構成し、1 メッセージ内で **並列 Agent 起動**。
機械チェックでフック関連項目（`hooks.json` JSON valid 等）はスキップ。

### Phase 4: 結果統合

5 名分の結果のみを統合。フック関連の指摘は出ない（チェック対象外のため）。

### Phase 5: 引き渡し

総合判定に応じて次のアクションを提案（フック追加検討の提案は不要）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | 5 名のメンバー結果に基づくレビュー（フック関連の所見なし） |
| 起動した security-engineer | **0 名**（コスト削減 + 関係ない指摘の排除） |
| 終了状態 | レビュー完了 |

## 分岐の根拠

`plugin-review-team` の構成は対象プラグインのフック含有有無で 5〜6 名と動的に変わる。
本ケースはフック非含有 → `security-engineer` を含めない 5 名構成。

## 関連ケース

- `case-02_plugin_review.md`（フック含有・6 名構成）
- `case-03_hook_review.md`（フック単体レビュー、`hook-security-team`）
