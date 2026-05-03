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
ただし **依存先マーケットプレイスを利用者が `/plugin marketplace add` で追加していない場合、Claude Code 公式仕様により依存は未解決のまま放置されます**（自動マーケ追加機構は存在しません）。
クロスマーケットプレイス依存（`plugin.json` の `dependencies` に **自プラグインの所属マーケ名と異なる** `marketplace` フィールドが含まれる場合）があるプラグインでは、以下 D-1 / D-2 / D-3 の 3 ブロックを **必須記載** してください（ADR-028 準拠）。
依存なし・同一マーケ依存のみのプラグインでは、本セクション全体を「依存関係なし」の 1 行に置き換えます（**セクションごとの省略は不可**）。

**D-1. 依存マーケットプレイスの追加（必須）**

```text
/plugin marketplace add {dependency-marketplace-url}
```

**D-2. 依存マーケットプレイスの自動更新有効化（必須）**

`~/.claude/settings.json` の `extraKnownMarketplaces` に依存マーケットプレイスを `autoUpdate: true` で登録します。これにより依存プラグインもセッション起動時に自動更新されます。自プラグインのマーケットプレイス登録（C 節）と同形式で並べて記述してください。

```json
{
  "extraKnownMarketplaces": {
    "{dependency-marketplace-name}": {
      "source": {
        "type": "github",
        "repo": "{owner}/{repo}"
      },
      "autoUpdate": true
    }
  }
}
```

複数の依存マーケットプレイスがある場合は `extraKnownMarketplaces` 配下に同形式で並べて登録してください。

**D-3. 依存プラグインの個別インストール（必須）**

```text
/plugin install {dependency-plugin-1}@{dependency-marketplace}
/plugin install {dependency-plugin-2}@{dependency-marketplace}
```

**Python 等の外部ツール依存**

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
