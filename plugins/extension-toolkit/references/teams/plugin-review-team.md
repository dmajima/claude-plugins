# Agent Team: plugin-review-team

プラグイン全体の横断レビューを多角的に実施するチーム。

## チーム情報

| 項目 | 内容 |
|------|------|
| 目的 | プラグインの構造妥当性・実装品質・evals 網羅性・マーケットプレイス適合・セキュリティを多角的に評価し合議で総合判定を導く |
| リード | `architect`（グローバル） |
| メンバー（リード以外） | `plugin-structure-reviewer` / `implementation-engineer`（グローバル） / `evals-coverage-reviewer` / `marketplace-fit-reviewer` / `security-engineer`（グローバル、フック含有時のみ） |
| 人数 | フック含有時 6 名（リード含む） / 非含有時 5 名（リード含む） |
| 議論ラウンド | 最低 3、上限 5 |

## 起動条件

- プラグイン全体のリリース前最終レビュー
- 大規模改修後の整合性検証
- `extension-reviewer` でプラグイン対象が指定された場合

## メンバー構成と専門性

| ID | 配布元 | 役割 | 専門性 | 主な評価軸 |
|----|--------|------|-------|----------|
| `architect` | グローバル | リード | システム構造 / 技術選定 | 全体構造妥当性・コンポーネント境界 |
| `plugin-structure-reviewer` | プラグイン同梱 | メンバー | 規約準拠 | conventions / ai-readability / readme-policy 準拠 |
| `implementation-engineer` | グローバル | メンバー | 実装品質 | SKILL.md / references / scripts の品質 |
| `evals-coverage-reviewer` | プラグイン同梱 | メンバー | テスト網羅 | 動作分岐の evals 網羅性 |
| `marketplace-fit-reviewer` | プラグイン同梱 | メンバー | マーケット適合 | 命名衝突 / 機能重複 / 依存解決 |
| `security-engineer` | グローバル | メンバー | セキュリティ | フック / 外部公開機能の安全性 |

注: フックを含むプラグインの場合 `security-engineer` を必ず含める（6 名構成）。フック未含有の場合は省略可（5 名構成）。いずれもリードを含む人数。

## 調整ガイドライン

- リード `architect` が論点を提示し、各メンバーが担当観点で初回評価
- メンバー間で反論・補強（特に `plugin-structure-reviewer` × `architect` の構造観点が衝突しやすい）
- 議論ラウンド最低 3 回。合意至らない項目はトレードオフを明示してユーザに判断を仰ぐ
- 機械チェック結果を統合して優先度付きの最終レポート

## グローバルエージェント不在時のフォールバック（ADR-022 準拠）

`architect` / `implementation-engineer` / `security-engineer` はグローバルエージェント（`~/.claude/agents/`）に依存している。利用者環境に存在しない場合のフォールバックを以下に定義する:

| 不在エージェント | フォールバック |
|---------------|------------|
| `architect` | `plugin-structure-reviewer`（同梱）にリード兼任。「全体構造観点」を `plugin-structure-reviewer` に追加プロンプトで指示 |
| `implementation-engineer` | `plugin-structure-reviewer`（同梱）が「実装品質観点」を兼任。または `general-purpose` に観点別プロンプトで委譲 |
| `security-engineer`（フック含有時） | `general-purpose` を `security-engineer` のプロンプトテンプレートで起動（[`../../agents/`](../../agents/) への将来同梱を予定） |
| `evals-coverage-reviewer` / `marketplace-fit-reviewer` / `plugin-structure-reviewer` | プラグイン同梱、不在ケースは想定外（インストールで自動配備） |

利用者が `/plugin install extension-toolkit@dmajima-claude-plugins` でプラグインをインストールすると、すべての同梱エージェントが自動配備される。グローバルエージェント不在環境ではメイン Claude が上記マッピングに従って `subagent_type` を切り替える。

## スポーンプロンプト

ADR-021（レビューフレッシュ起動原則）に従い、過去レビュー結論・修正履歴を引き継がず、必須引き継ぎ事項のみで起動する。

```text
plugin-review-team チームを作成し、以下のプラグインを多角的に議論してください。

メンバー構成:
- architect エージェントをリードとして、全体構造の論点提示・合意形成を担当
- plugin-structure-reviewer エージェントが規約準拠を評価
- implementation-engineer エージェントが SKILL.md / references / scripts の実装品質を評価
- evals-coverage-reviewer エージェントが動作分岐の evals 網羅性を評価
- marketplace-fit-reviewer エージェントがマーケット適合性を評価
- security-engineer エージェントがフック・外部公開機能の安全性を評価（フック未含有なら省略）

対象: {{プラグインパス}}
背景: {{公開予定 / 改修内容 / 公開先マーケットプレイス}}

最低 3 回の議論ラウンドを経て、合意形成された総合判定（APPROVE / CONDITIONAL_APPROVE / REJECT）と
重大度別指摘リストをレポートにまとめてください。合意至らない項目はトレードオフとして明記してください。

注意: 過去の議論・修正履歴・他レビュアーの結論は与えていません。これらに依らず、対象を白紙で評価してください。
「修正済み」「対応完了」等のメタ評価を前提とせず、現時点のファイル内容のみで判断してください。
```
