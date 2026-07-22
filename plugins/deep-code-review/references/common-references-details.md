# 観点別レビュースキル 共通リファレンス（詳細・条件付き参照）

`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` のうち、実行フロー（手順 1〜4）で毎回は必要としないインデックス情報を分離したファイル。common-references.md のセクション 1 / 2 / 3 に対応し、該当時のみ Read する。実行フローで毎回必要なセクション 4 / 4.5 / 5 は common-references.md 本体に残す。

---

## 1. プラグイン共通リファレンス（必須）

| ファイル | 内容 | 主な利用タイミング |
|---------|------|-------------------|
| `${CLAUDE_PLUGIN_ROOT}/references/agents.md` | エージェント選定とプロンプト構成 | エージェント起動前 |
| `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` | 重要度付与基準・重複統合ルール | 中間レポート生成時 |
| `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` | 別 PR 推奨禁止 / PR 外への影響禁止 | 指摘分類・出力時 |
| `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` | コメント本文サニタイズ・予約文字エスケープ・機密文字列伏字化 | レビュー結果返却前 |
| `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` | 全スキルのルール ID 体系（Universal / Observation / Coordinator / PR Adapter / Inference / Environment） | スキル設計・改訂時 |
| `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` | Universal ルール U1〜U16 の規範本文・達成基準 | 完了前チェック |
| `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` | 言語・FW 検出手順と観点プロファイル対応表 | 言語プロファイル未受領時の自己検出 |
| `${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` | レビュー基準（規約）の 5 段階優先順位解決 | 規約系指摘の根拠決定時 |
| `${CLAUDE_PLUGIN_ROOT}/references/languages/CLAUDE.md` | 言語別レビュー観点プロファイル（8 言語）の読み込みガイド | エージェント起動前 |

## 2. オーケストレーター連携

統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。本観点別スキルは **中間レポート**（各 SKILL.md の「出力フォーマット」セクションの形式）を返すのみ。

| ファイル | 内容 |
|---------|------|
| `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/output/output-format.md` | 統合サマリ出力フォーマット規範 |
| `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` | 統合サマリテンプレート |

## 3. 達成チェックリスト（個別スキル）

各観点別スキルは独自の `references/checklist.md` を持つ。Universal U1〜U16 の達成基準は本ファイルではなく `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` で管理。

各スキルの checklist 配置:
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review-implementation/references/checklist.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review-testing/references/checklist.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review-security/references/checklist.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review-architecture/references/checklist.md`
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review-frontend/references/checklist.md`
