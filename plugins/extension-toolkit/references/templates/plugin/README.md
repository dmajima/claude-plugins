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

## 導入手順

### 前提

- Claude Code がインストール済み
- {依存プラグインがあれば記載、なければ「依存なし」と明示}

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add {marketplace-url}
/plugin install {plugin-name}@{marketplace-name}
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone {repo-url} <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout {tag-or-branch}
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install {plugin-name}@{marketplace-name}
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "{marketplace-name}": {
      "source": { "...": "..." },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

`plugin.json` の `dependencies` で宣言された依存プラグインは、利用者のマーケットプレイスで `allowCrossMarketplaceDependenciesOn` が許可されていれば自動インストールされます。
**自動インストールが成立しない場合**（別マーケットプレイスへの参照が許可されていない・ネットワーク制約等）は、以下の手順で個別にインストールします:

```text
# 依存マーケットプレイスを追加
/plugin marketplace add {dependency-marketplace-url}

# 依存プラグインを明示インストール
/plugin install {dependency-plugin-1}@{dependency-marketplace}
/plugin install {dependency-plugin-2}@{dependency-marketplace}
```

依存なしの場合は「依存関係なし」と明示してください。

#### Python 等の外部ツール依存

スキル内で Python venv 等の外部ツールを使う場合、利用者環境に導入されている前提となる外部ツールをここに列挙します:

- {例: Python 3.10+}
- {例: git 2.30+}

### 動作確認

```text
/{command-name} --help
```

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

このプラグインが特定の外部システム・URL に依存する場合のみ記載します。該当なしの場合はこのセクションごと削除してください。

| システム | 用途 | 参照箇所 |
|---------|------|---------|
| {URL or path} | {用途} | {ファイルパス} |
