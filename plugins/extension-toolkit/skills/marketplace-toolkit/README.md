# marketplace-toolkit (skill)

Claude Code のプラグインマーケットプレイスを **新規構築** し、`.claude-plugin/marketplace.json` とマーケットプレイス直下 README の同期を担当するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- マーケットプレイスの新規構築（リポジトリ初期化 + `marketplace.json` + マーケットプレイス README）
- 既存マーケットプレイスへのプラグイン追加・更新・削除（`marketplace.json` 編集 + README 同期）
- マーケットプレイス直下 README の生成・同期（ADR-019 準拠）

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「新しいマーケットプレイス `acme-claude-plugins` を作って」
- 「`marketplace.json` に `bar` プラグインを追加」

または `/extension marketplace <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> 新しいマーケットプレイス `acme-claude-plugins` を作って

Claude（要約）:
> テンプレート展開 → marketplace.json + マーケットプレイス README 生成 → ADR-019 同期

## トリガー例

- 「新しいマーケットプレイス `foo` を作って」
- 「`marketplace.json` に `bar` プラグインを追加」
- 「マーケットプレイス README を最新化」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | 新規構築後に最初のプラグインを作る |
| `marketplace-publish` | プラグインの公開ワークフロー（git push / PR）を担当、本スキルを内部で呼び出す |
| `readme-toolkit` | プラグイン・スキル単位の README を担当（マーケットプレイス README は本スキル） |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/operations.md` | モード判定と各操作の詳細 |
| `references/readme-sync.md` | マーケットプレイス README 同期ロジック |
| `evals/` | 動作分岐の期待挙動 |
