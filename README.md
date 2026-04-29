# dmajima-claude-plugins

wwdmajima 個人用 Claude Code プラグインマーケットプレイス。

## 構成

```
dmajima-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json    # マーケットプレイス定義
└── plugins/                # プラグイン格納先（プラグイン追加時に配置）
```

## プラグイン追加手順

1. `plugins/{plugin-name}/` ディレクトリを作成し、プラグインを配置する
2. `.claude-plugin/marketplace.json` の `plugins[]` にエントリを追加する
3. コミットして反映する

## 利用方法

ローカル登録済み (`~/.claude/settings.json` の `extraKnownMarketplaces`)。
Claude Code 起動時に自動で更新がチェックされる (`autoUpdate: true`)。
