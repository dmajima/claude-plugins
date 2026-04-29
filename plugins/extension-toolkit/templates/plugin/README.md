# {plugin-name}

{プラグインの目的を 1〜2 文で記載}

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `{name-1}` | スキル | {説明} |
| `/{command}` | コマンド | {説明} |
| `{agent-name}` | エージェント | {説明} |

## 使い方

### スラッシュコマンド

```text
/{command-name} <引数>
```

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「{トリガーフレーズ例 1}」 | `{name-1}` |
| 「{トリガーフレーズ例 2}」 | `{name-2}` |

## ファイル構成

```text
plugins/{plugin-name}/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/
├── skills/
├── agents/
├── hooks/
└── references/
```

## 依存システム（External Dependencies）

このプラグインが特定の外部システム・URL に依存する場合のみ記載する。該当なしの場合はこのセクションごと削除する。

| システム | 用途 | 参照箇所 |
|---------|------|---------|
| {URL or path} | {用途} | {ファイルパス} |

## 利用方法

```text
/plugin install {plugin-name}@{marketplace-name}
```
