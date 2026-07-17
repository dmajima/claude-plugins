# 観点別レビュースキル 共通リファレンス（SSOT）

`code-review-implementation` / `code-review-testing` / `code-review-security` / `code-review-architecture` / `code-review-frontend` の **5 スキル共通で参照する** リファレンス一覧。

> **位置付け**: `${CLAUDE_PLUGIN_ROOT}/references/common-references.md`（プラグイン共通 references）。
> 各観点別スキルの SKILL.md からは本ファイルを片方向参照する形に統一（共通化済み）。
> 本ファイル → 個別スキルへの参照は持たない。

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

## 4. 観点別スキル共通: 進捗管理（5 スキル共通）

観点別 5 スキル（impl / testing / security / architecture / frontend）はすべて **複数エージェントの並列起動を伴う** ため、Universal U5（進捗管理）が必須。
オーケストレーター（`code-review`）が `progress.md` を作成・維持している場合は、本スキルは担当タスク（各エージェントの起動・結果取得）を `progress.md` に追記する。
オーケストレーター不在時（観点別スキル単独実行）は本スキル自身で `progress.md` を作成・維持する。

詳細規範: `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U5

## 4.5 観点別スキル共通: 言語別レビュー観点プロファイルの適用（O10）

観点別 5 スキルは、内部エージェントを起動する際に **検出済み言語・FW の観点プロファイルをプロンプトに含める**:

1. オーケストレーターから `language-profiles=<...>` 引数（適用プロファイルパス一覧 + 主/副区分）を受け取る
2. 引数が無い場合（単独実行時）は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の手順で自己検出する
3. 各エージェントのプロンプトに以下を含める:

```
## 言語別レビュー観点
検出言語・FW: <一覧>
以下のプロファイルを Read し、あなたの担当観点（【担当】表記参照）を評価に使用せよ:
- ${CLAUDE_PLUGIN_ROOT}/references/languages/<言語>.md
- ${CLAUDE_PLUGIN_ROOT}/references/frameworks/<FW>.md
プロジェクト独自規約（適用規約サマリ）が最優先。プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する（conventions-resolution.md の 5 段階解決）。
```

4. 未対応言語（プロファイル無し）が含まれる場合は、中間レポートの制約事項に「<言語>: 観点プロファイル未収録・汎用観点のみで評価」と明記する

エージェント別の主担当プロファイル:

| エージェント | 主に参照するプロファイル |
|-------------|----------------------|
| implementation-engineer | 検出言語の languages/*.md（観点 3.1〜3.5, 3.8）+ 該当 frameworks/*.md |
| performance-reviewer | 検出言語の languages/*.md（観点 3.6）+ 該当 frameworks/*.md の性能観点 |
| security-engineer | 検出言語の languages/*.md（観点 3.7）+ 該当 frameworks/*.md のセキュリティ観点 |
| linter-static-analysis / test-runner | 検出言語の languages/*.md（動的検証コマンド） |
| dba | languages/sql.md + frameworks/orm.md |
| web-designer | languages/html.md + languages/css.md + 該当 frameworks/*.md（react / vue / frontend-tooling） |
| test-engineer | 検出言語の languages/*.md（動的検証コマンドのテスト規約）+ frameworks/frontend-tooling.md のテスト観点 |
| architect / dependency-safety | 必要に応じて該当 frameworks/*.md |

## 5. 観点別スキル共通: スコープ外振分けルール

各観点別スキルは自スキルのスコープ外と判断した指摘を、対応する他観点別スキルへ誘導する:

| 自スキル | スコープ外時の振分け先 |
|---------|--------------------|
| `code-review-implementation` | テスト → `code-review-testing` / セキュリティ → `code-review-security` / アーキ → `code-review-architecture` / UI → `code-review-frontend` |
| `code-review-testing` | 実装 → `code-review-implementation` / E2E・性能テスト・脆弱性スキャン → 対象外 |
| `code-review-security` | 実装一般 → `code-review-implementation` / テスト → `code-review-testing` / 実装提案 → 自スキル内では指摘のみ |
| `code-review-architecture` | 実装一般 → `code-review-implementation` / テスト → `code-review-testing` / セキュリティ → `code-review-security` / UI → `code-review-frontend` |
| `code-review-frontend` | バックエンド → `code-review-implementation` / API 設計 → `code-review-architecture` / XSS 重点 → `code-review-security` |

「別 PR 推奨」「Issue 起票」等の文言は使わない（`scope-out-policy.md` セクション1）。本 PR スコープ外指摘はオーケストレーターが「## 3. スコープ外指摘」セクションに集約する。

---

## 6. 適用契約

本ファイルは **観点別 5 スキルが共通参照する** リファレンス・共通規範をまとめたインデックス。
個別スキルからの参照リストは本ファイル経由で 1 行にまとまり、規範改訂時のメンテナンスコストが下がる。
