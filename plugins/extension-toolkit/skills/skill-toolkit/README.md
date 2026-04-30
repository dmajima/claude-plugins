# skill-toolkit (skill)

Claude Code のスキル一式（SKILL.md / README.md / references / scripts / evals）を新規作成・改修するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。スキル動作の本体は `SKILL.md` および `references/` 配下を参照する。

## 責務（要約）

スキル単体の生成・改修のみ。プラグイン外形・コマンド・エージェント・フック・公開は他スキルが担当。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「`code-formatter` スキルを作って」
- 「`my-skill` を改修したい」

または `/extension skill <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> 新しいスキル `code-formatter` を作って

Claude（要約）:
> テンプレートから外形作成 → ユーザに観点・分岐を確認 → SKILL.md 生成 → evals 雛形 → README

## トリガー例

- 「新しいスキル `foo` を作って」
- 「`bar` スキルに機能追加」
- 「○○用のスキルが欲しい」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | スキルをプラグイン内に配置する場合、外形作成を依頼 |
| `command-toolkit` | スキルと一緒にコマンドも作る場合に併用 |
| `agent-toolkit` | スキル内でサブエージェントを使う場合に併用 |
| `extension-reviewer` | 完成後のレビュー |
| `marketplace-publisher` | プラグイン化後の公開 |

## 依存外部スキル（任意参照）

| 依存先 | 用途 |
|-------|------|
| `example-skills@anthropic-agent-skills` | スキル雛形・ベストプラクティス参照 |
| `document-skills@anthropic-agent-skills` | ドキュメント生成系スキル参照 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/procedures.md` | 新規生成・既存改修の詳細手順 |
| `references/external-dependencies.md` | 依存外部スキルの利用方法 |
| `evals/` | 動作分岐の期待挙動 |
