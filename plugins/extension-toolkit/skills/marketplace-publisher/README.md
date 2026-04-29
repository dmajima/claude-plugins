# marketplace-publisher (skill)

Claude Code プラグインマーケットプレイスへの登録・更新・公開ワークフローを担当するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

`marketplace.json` の更新、重複・マージチェック、公開ワークフロー（ハンドオフ / フルオート）の実行。プラグイン本体作成は他スキルが担当。

## トリガー例

- 「`dev-toolkit` プラグインを公開」
- 「marketplace.json に `foo` を登録」
- 「`bar` の重複チェック」
- 「フルオートで公開」

## 公開モード

| モード | 動作 |
|-------|------|
| ハンドオフ（既定） | git コマンドを提示。ユーザがコミット・プッシュ・PR 作成 |
| フルオート | git push + PR 作成まで自動実行（main 直接 push は禁止） |

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | このスキルが登録対象とするプラグインの本体作成 |
| `extension-reviewer` | 公開前のレビュー |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/marketplace-json.md` | marketplace.json のスキーマ・更新ルール |
| `references/duplication-check.md` | 既存プラグインとの重複・マージ判定 |
| `references/publish-workflow.md` | ハンドオフ / フルオートの手順 |
| `evals/` | 動作分岐の期待挙動 |
