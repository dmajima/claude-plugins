# extension-reviewer (skill)

Claude Code の拡張要素（スキル・プラグイン・マーケットプレイス・コマンド・エージェント・チーム・フック）を多角的に横断レビューするスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

複数の専門エージェント（最低 3 名）を **フレッシュインスタンス（ADR-021）** で並列起動して観点別レビューを実施し、結果を統合・優先度付けして提示する。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「`code-formatter` スキルをレビュー」
- 「`dev-toolkit` プラグイン全体をチェック」

または `/extension review <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> `extension-toolkit` プラグインをレビュー

Claude（要約）:
> 対象判定 → フレッシュ Agent で 6 名並列レビュー → 結果統合・優先度付け

## トリガー例

- 「`code-formatter` スキルをレビュー」
- 「`dev-toolkit` プラグイン全体をチェック」
- 「`dmajima-claude-plugins` マーケットプレイスをレビュー」
- 「公開前に多角レビュー」

## 内部利用エージェント

レビュー対象に応じて以下を並列起動:

### プラグイン同梱（`agents/` 配下、利用者環境に依らず常に利用可能）

| エージェント | 観点 |
|------------|------|
| `plugin-structure-reviewer` | 規約準拠（conventions / ai-readability / readme-policy） |
| `evals-coverage-reviewer` | evals 網羅性 |
| `description-trigger-reviewer` | description のトリガー精度 |
| `marketplace-fit-reviewer` | マーケットプレイス整合・命名衝突・依存解決 |

### グローバル既存（`~/.claude/agents/`、利用者環境に依存）

| エージェント | 観点 | 不在時フォールバック |
|------------|------|------------------|
| `architect` | 構造妥当性・設計判断 | `plugin-structure-reviewer` がリード兼任 |
| `implementation-engineer` | 実装品質・正確性 | `plugin-structure-reviewer` または `general-purpose` |
| `security-engineer` | セキュリティ（command・フック・外部公開） | `general-purpose` を専門性プロンプトで起動 |
| `test-engineer` | テスト・evals 充実度 | `evals-coverage-reviewer`（同梱）が部分代替 |
| `project-leader` | 大規模プラグインの整合性 | `general-purpose` |

詳細なフォールバック設計は [`../../references/self-containment.md`](../../references/self-containment.md) を参照。

## 関連スキル

| スキル | 関係 |
|-------|------|
| `*-toolkit` | レビュー指摘の修正で再起動 |
| `marketplace-toolkit` | マーケットプレイス本体（marketplace.json + マーケットプレイス README）レビュー後の修正 |
| `marketplace-publisher` | レビュー合格後の公開 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/review-perspectives.md` | 対象別レビュー観点とエージェント選定 |
| `references/team-selection.md` | 対象別チーム / エージェントの採用ルール |
| `references/automated-checks.md` | 機械的チェック項目とその実行方法 |
| `evals/` | 動作分岐の期待挙動 |
