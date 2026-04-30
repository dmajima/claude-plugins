# dmajima-claude-plugins

dmajima 個人用 Claude Code プラグインマーケットプレイス。

## プラグイン一覧

| 名前 | バージョン | 説明 | カテゴリ |
|------|-----------|------|---------|
| [credentials-manager](plugins/credentials-manager/) | — | Claude Code セッションをまたいで認証情報を保存・自動適用するプラグイン | security |
| [extension-toolkit](plugins/extension-toolkit/) | — | Claude Code 拡張要素（プラグイン/スキル/コマンド/エージェント/フック）の作成からマーケットプレイス構築・公開まで支援 | — |
| [convert-doc](plugins/convert-doc/) | 1.0.0 | Markdown を HTML / PDF / PowerPoint（PPTX）に Wiki スタイルで一括変換できる 3 スキル + 4 コマンド同梱のドキュメント変換プラグイン | documentation |

> バージョン欄が `—` のプラグインは `plugin.json` でバージョンを管理しないか、別の方式で管理されています。

## マーケットプレイスの追加方法

### A. URL 経由で追加する（推奨）

GitHub 上の本リポジトリを Claude Code に登録します。

```text
/plugin marketplace add dmajima/claude-plugins
```

または明示的に URL を指定:

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
```

登録後、利用したいプラグインを個別にインストールしてください。

```text
/plugin install convert-doc@dmajima-claude-plugins
/plugin install credentials-manager@dmajima-claude-plugins
/plugin install extension-toolkit@dmajima-claude-plugins
```

### B. ローカル複製で追加する

リポジトリをクローンして、ローカルパスを Claude Code に登録します。

```bash
git clone https://github.com/dmajima/claude-plugins.git
```

```text
/plugin marketplace add /path/to/claude-plugins
```

ローカル複製方式は、プラグイン本体の改修やデバッグを行いたい場合に推奨されます。

## 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` セクションに以下を追記すると、Claude Code 起動時に自動で更新がチェックされます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "owner": "dmajima",
        "repo": "claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: true` を設定すると最低週1回の更新チェックを実現できます。詳細は `~/.claude/rules/claude/plugin-auto-update.md` を参照してください。

## リポジトリ構成

```
dmajima-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json    # マーケットプレイス定義
├── README.md               # このファイル
└── plugins/                # プラグイン格納先
    ├── convert-doc/
    ├── credentials-manager/
    └── extension-toolkit/
```

## メンテナ向け: プラグイン追加手順

1. `plugins/{plugin-name}/` ディレクトリを作成し、プラグインを配置する
2. `.claude-plugin/marketplace.json` の `plugins[]` にエントリを追加する
3. 本 README のプラグイン一覧テーブルに行を追加する
4. コミットして反映する

## ライセンス

各プラグイン個別のライセンスに従います。プラグインルートに `LICENSE` ファイルが存在する場合はそれを優先します。
