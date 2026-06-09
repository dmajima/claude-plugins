# hook-toolkit (skill)

Claude Code のフック設定（`hooks.json` または `settings.json` の `hooks`）を作成・改修するスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス**。Claude Code がスキル動作中に参照することはない。

## 責務（要約）

フック設定ファイルの作成・改修のみ。`settings.json` からのフック抽出（プラグイン化）は `plugin-toolkit` の移管シナリオが担当。

## 導入手順

### 前提

- Claude Code がインストール済み
- `extension-toolkit` プラグインがインストール済み（[プラグイン README の導入手順](../../README.md) 参照）

### 起動方法

以下のフレーズで自動起動します:

- 「PreToolUse フックで Bash 実行をログ」
- 「Stop イベントで通知音」

または `/extension hook <対象>` 経由で起動できます（[`/extension` コマンド](../../commands/extension.md)）。

## 利用方法（最小例）

ユーザ:
> PreToolUse フックで Bash 実行をログ

Claude（要約）:
> イベント・matcher・command 設計 → テンプレート展開 → セキュリティ確認 → JSON 生成

## トリガー例

- 「`PreToolUse` フックで Bash ログ」
- 「`Stop` イベントで通知音」
- 「セッション開始時に環境変数を出力」

## 関連スキル

| スキル | 関係 |
|-------|------|
| `plugin-toolkit` | `settings.json` からのフック抽出（移管シナリオ） |
| `extension-review` | 完成後のフック設定レビュー |
| `marketplace-publish` | プラグイン同梱フックの公開 |

## 主要参照ファイル

| ファイル | 内容 |
|---------|------|
| `SKILL.md` | スキル定義とトリガー条件 |
| `references/hook-events.md` | イベント別の使い方とサンプル |
