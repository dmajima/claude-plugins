# plugin-toolkit (skill)

Claude Code のプラグイン外形（`plugin.json` / `README.md` / ディレクトリ）を作成し、既存スキル/コマンド/フック/エージェントをプラグイン構造に移管（コピー）するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

プラグイン **外形構築 + 既存資産の移管** のみ。中身（スキル本体・コマンド本体等）の生成は他スキルが担当。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「新しいプラグイン `dev-toolkit` を作って」
- 「既存スキル `bar` をプラグイン化」

または `/extension plugin <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> 新しいプラグイン `dev-toolkit` を作って

Claude（要約）:
> 外形作成（plugin.json + ディレクトリ） → 既存資産があれば移管 → README 雛形

## トリガー例

- 「新しいプラグイン `dev-toolkit` を作って」
- 「既存スキル `code-formatter` をプラグイン化」
- 「`dev-toolkit` に既存スキル追加」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `skill-toolkit` | 外形作成後にスキル本体を生成 |
| `command-toolkit` | 外形作成後にコマンド本体を生成 |
| `agent-toolkit` | 外形作成後にエージェント本体を生成 |
| `hook-toolkit` | 外形作成後にフック設定を生成 |
| `marketplace-publisher` | プラグイン完成後の公開 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/procedures.md` | 新規外形・移管・追加配置の詳細手順 |
| `references/migration-rules.md` | 既存資産の移管マッピング |
| `evals/` | 動作分岐の期待挙動 |
