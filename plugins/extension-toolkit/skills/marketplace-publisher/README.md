# marketplace-publisher (skill)

Claude Code プラグインの **公開ワークフロー**（重複検査・実体検証・git push・PR 作成・ハンドオフ or フルオート）を担当するスキル。`marketplace.json` 編集とマーケットプレイス README 同期は `marketplace-toolkit` に委譲する（ADR-020）。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

公開ワークフローの実行（重複・マージチェック → 実体検証 → シークレット混入スキャン → `marketplace-toolkit` への委譲 → git push / PR 作成）。`marketplace.json` の編集ロジックとマーケットプレイス README 同期そのものは `marketplace-toolkit` の責務。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「`extension-toolkit` を公開」
- 「フルオートで公開」

または `/extension publish <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> `extension-toolkit` プラグインを公開

Claude（要約）:
> 重複検査 → シークレットスキャン → marketplace-toolkit 委譲 → git push → PR 作成

## トリガー例

- 「`dev-toolkit` プラグインを公開」
- 「`bar` の重複チェック」
- 「フルオートで公開」

`marketplace.json` を直接編集したい場合や、マーケットプレイス README を同期したい場合は `marketplace-toolkit` を使用する。

## 公開モード

| モード | 動作 |
|-------|------|
| ハンドオフ（既定） | git コマンドを提示。ユーザがコミット・プッシュ・PR 作成 |
| フルオート | git push + PR 作成まで自動実行（main / master 直接 push は禁止、シークレット検出時は fail-closed） |

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | このスキルが登録対象とするプラグインの本体作成 |
| `marketplace-toolkit` | `marketplace.json` 編集 + マーケットプレイス README 同期を委譲（ADR-020）。本スキルが Skill ツール経由で呼び出す |
| `extension-reviewer` | 公開前のレビュー |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/marketplace-json.md` | marketplace.json のスキーマ概要（編集ロジックは `marketplace-toolkit` 側 SSOT を参照） |
| `references/duplication-check.md` | 既存プラグインとの重複・マージ判定 |
| `references/secret-scan.md` | シークレット混入スキャンの検出パターンと fail-closed フロー |
| `references/publish-workflow.md` | ハンドオフ / フルオートの手順、ブランチ判定、git/gh 連携 |
| `evals/` | 動作分岐の期待挙動 |
