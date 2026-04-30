# Agent Team: skill-review-team

スキル単体の構造・実装・evals を多角的にレビューするチーム。

## チーム情報

| 項目 | 内容 |
|------|------|
| 目的 | スキル単体（SKILL.md / references / scripts / evals）の構造妥当性・実装品質・evals 網羅性を評価する |
| リード | `plugin-structure-reviewer` |
| メンバー（リード以外） | `implementation-engineer`（グローバル） / `evals-coverage-reviewer` |
| 人数 | 3 名（リード含む） |
| 議論ラウンド | 最低 3、上限 5 |

## 起動条件

- スキル新規作成完了後の自己レビュー
- 既存スキル改修後の影響評価
- `extension-reviewer` でスキル対象が指定された場合

## メンバー構成と専門性

| ID | 配布元 | 役割 | 専門性 | 主な評価軸 |
|----|--------|------|-------|----------|
| `plugin-structure-reviewer` | プラグイン同梱 | リード | 規約準拠 | SKILL.md / references / README 構造 |
| `implementation-engineer` | グローバル | メンバー | 実装品質 | SKILL.md の論理整合・procedures の実行可能性 |
| `evals-coverage-reviewer` | プラグイン同梱 | メンバー | テスト網羅 | evals の分岐網羅・形式準拠 |

description 観点は本チームに含めない。`description-trigger-reviewer` は他のスキルレビュー時にも単独で並列起動する運用とする（運用詳細は [`../agent-utilization.md`](../agent-utilization.md) のセクション「単独並列起動するエージェント」を参照）。チーム内に組み込むと議論ラウンドで他観点と混ざり、description 専門評価の独立性が損なわれるため。

## 調整ガイドライン

- リード `plugin-structure-reviewer` が SKILL.md の構造評価を提示
- `implementation-engineer` が procedures の論理を検証
- `evals-coverage-reviewer` が evals の網羅性をチェック
- 3 観点の重複指摘は集約、矛盾はユーザに提示
- 議論ラウンド最低 3、上限 5

## グローバルエージェント不在時のフォールバック（ADR-022 準拠）

| 不在エージェント | フォールバック |
|---------------|------------|
| `implementation-engineer` | `plugin-structure-reviewer`（同梱）が「実装品質観点」を兼任、または `general-purpose` を `implementation-engineer` のプロンプトテンプレートで起動 |

`plugin-structure-reviewer` / `evals-coverage-reviewer` はプラグイン同梱のため、インストール直後から利用可能。

## スポーンプロンプト

ADR-021（レビューフレッシュ起動原則）に従い、過去レビュー結論・修正履歴を引き継がず、必須引き継ぎ事項のみで起動する。

```text
skill-review-team チームを作成し、以下のスキルを多角的にレビューしてください。

メンバー構成:
- plugin-structure-reviewer エージェントをリードとして、SKILL.md / references / README の構造妥当性を評価
- implementation-engineer エージェントが procedures の実装可能性・論理整合を評価
- evals-coverage-reviewer エージェントが evals の網羅性を評価

対象スキル: {{skill_path}}
背景: {{新規作成 / 改修内容}}

最低 3 回の議論ラウンドを経て、合意形成された総合判定と重大度別指摘リストをレポートにまとめてください。

注意: 過去の議論・修正履歴・他レビュアーの結論は与えていません。これらに依らず、対象を白紙で評価してください。
「修正済み」「対応完了」等のメタ評価を前提とせず、現時点のファイル内容のみで判断してください。
```
