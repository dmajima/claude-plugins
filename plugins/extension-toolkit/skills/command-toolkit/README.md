# command-toolkit (skill)

Claude Code のスラッシュコマンドファイル（`commands/{name}.md`）を作成・改修するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

スラッシュコマンドファイルの生成・改修のみ。スキル本体・プラグイン外形等は他スキルが担当。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「新しい `/foo` コマンドを作って」
- 「`/bar` コマンドを更新」

または `/extension command <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> 新しい `/foo` コマンドを作って

Claude（要約）:
> テンプレート展開 → frontmatter description 整合確認 → 命名衝突チェック → ファイル生成

## トリガー例

- 「新しい `/extension` コマンドを作って」
- 「`/foo` コマンドにルーティング追加」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | プラグイン内に配置する場合の外形作成 |
| `skill-toolkit` | コマンドからルーティングするスキル本体作成 |
| `extension-review` | 完成後のレビュー |
| `marketplace-publish` | プラグイン化後の公開 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/procedures.md` | 詳細手順 |
