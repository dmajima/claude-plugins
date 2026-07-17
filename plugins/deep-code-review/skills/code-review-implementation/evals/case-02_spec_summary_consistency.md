# case-02 spec_summary 指定あり（仕様整合性チェックの追加）

委譲 args に `spec_summary=<要約>` が含まれるケース。implementation-engineer が通常の実装品質観点に加えて仕様整合性（実装漏れ・仕様逸脱・仕様矛盾）を追加観点として評価することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> mode=standard spec_summary=<仕様書要約>` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |

## 分岐の根拠

SKILL.md「入力（呼び出し時の引数）」表の「仕様書サマリ（任意）」行「`spec_summary=<要約>` 形式。指定がある場合は implementation-engineer が 仕様整合性 を追加観点として評価する」、SKILL.md「仕様整合性チェック（仕様書指定時のみ）」の観点表（実装漏れ / 仕様逸脱 / 仕様矛盾）、references/checklist.md セクション B O7 およびセクション D の「O7（仕様逸脱検出漏れ）」行、`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション 3（O7 は impl のみ適用）。

## 期待動作

- `spec_summary` を implementation-engineer のプロンプトに含めて起動し、仕様整合性を追加観点として評価させる（SKILL.md「入力（呼び出し時の引数）」）
- 実装漏れ（仕様書記載があるが実装されていない機能・パラメータ・エラーケース）を検出対象に含める（SKILL.md「仕様整合性チェック（仕様書指定時のみ）」）
- 仕様逸脱（仕様書と異なる挙動・命名・I/F）および仕様矛盾（実装と仕様書の根本的な乖離）を検出対象に含める（同上）
- linter-static-analysis / performance-reviewer は通常通り並列起動する（追加観点が付くのは implementation-engineer のみ。checklist.md O1）
- 検出した仕様整合性の指摘も、通常の指摘と同じ必須項目・重要度付きで中間レポートに含める（SKILL.md「実行フロー」手順 4）
- 仕様整合性チェックの評価漏れがあった場合は、spec_summary を再読込し implementation-engineer に追加観点を渡して再実行する（checklist.md セクション D「O7（仕様逸脱検出漏れ）」）

## 関連ケース

- case-01: spec_summary なし（仕様整合性チェックをスキップ）
