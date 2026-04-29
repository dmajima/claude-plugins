# extension-reviewer (skill)

Claude Code の拡張要素（スキル・プラグイン・コマンド・エージェント・チーム・フック）を多角的に横断レビューするスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

複数の専門エージェント（最低 3 名）を並列起動して観点別レビューを実施し、結果を統合・優先度付けして提示する。

## トリガー例

- 「`code-formatter` スキルをレビュー」
- 「`dev-toolkit` プラグイン全体をチェック」
- 「公開前に多角レビュー」

## 内部利用エージェント

レビュー対象に応じて以下を並列起動:

| エージェント | 観点 |
|------------|------|
| `implementation-engineer` | 実装品質・正確性 |
| `architect` | 構造妥当性・設計判断 |
| `security-engineer` | セキュリティ（command・フック・外部公開） |
| `test-engineer` | テスト・evals 充実度 |
| `project-leader` | 大規模プラグインの整合性 |

## 関連スキル

| スキル | 関係 |
|-------|------|
| `*-toolkit` | レビュー指摘の修正で再起動 |
| `marketplace-publisher` | レビュー合格後の公開 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/review-perspectives.md` | 対象別レビュー観点とエージェント選定 |
| `references/automated-checks.md` | 機械的チェック項目とその実行方法 |
| `evals/` | 動作分岐の期待挙動 |
