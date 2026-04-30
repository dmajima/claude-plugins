# dmajima-claude-plugins

dmajima 個人用 Claude Code プラグインマーケットプレイス。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code が動作中に参照することはありません。マーケットプレイス本体の定義は `.claude-plugin/marketplace.json` にあります。

## プラグイン一覧

各プラグインの詳細は `plugins/{plugin-name}/README.md` を参照してください。

| プラグイン | 説明 | バージョン | インストール |
|----------|------|----------|----------|
| `extension-toolkit` | Claude Code 拡張要素（プラグイン/スキル/コマンド/エージェント/フック）の作成からマーケットプレイス構築・公開まで支援 | 0.10.3 | `/plugin install extension-toolkit@dmajima-claude-plugins` |

## マーケットプレイスの追加方法

利用者環境に応じて以下のいずれかでマーケットプレイスを Claude Code に登録します。

### A. リモート URL 経由で追加（推奨）

公開リポジトリへのアクセスがある環境向け。

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
```

### B. ローカル複製で追加（オフライン・企業内環境向け）

公開リポジトリにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグ（推奨）またはブランチに切替
cd <local-path>
git checkout v{x.y.z}   # 推奨: 特定リリースタグを指定（最新タグは plugins/extension-toolkit/.claude-plugin/plugin.json の version、または `git tag --sort=-v:refname | head -1` を参照）
# 厳密な再現性が必要な場合はコミット SHA を直接指定: git checkout <commit-sha>
# または: git checkout main   # 最新版を追従（上流変更を取り込みます）
```

企業内・オフライン環境では、`main` 追従よりも検証済みリリースタグ + 自動更新無効化（後述）の組み合わせが安全です。

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>
```

両方式とも、登録後は `/plugin install {plugin-name}@dmajima-claude-plugins` で個別プラグインをインストールできます。

## 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、Claude Code セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "repo": "dmajima/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

ローカル複製で登録した場合は `source.type` を `"path"` 等に置換してください（環境に応じた設定は Claude Code のドキュメントを参照）。

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

## 依存マーケットプレイス

`marketplace.json` で `allowCrossMarketplaceDependenciesOn: ["anthropic-agent-skills"]` を宣言しています。これにより本マーケットプレイス内のプラグインが `anthropic-agent-skills` マーケットプレイス（Anthropic 公式）のプラグインを `dependencies` として宣言可能です。

| 依存マーケットプレイス | 用途 | 利用プラグイン | 個別追加（自動解決不可時） |
|------------------|-----|------------|----------------------|
| `anthropic-agent-skills` | スキル雛形・ドキュメント生成系の参考実装 | `extension-toolkit`（`example-skills` / `document-skills` を依存宣言） | `/plugin marketplace add https://github.com/anthropics/skills` |

依存マーケットプレイスは `allowCrossMarketplaceDependenciesOn` で許可していれば自動解決されます。許可されていない / ネットワーク制約がある環境では、利用者が手動で依存マーケットプレイスを追加してください。

## プラグイン追加手順（メンテナ向け）

1. `plugins/{plugin-name}/` ディレクトリを作成し、プラグインを配置する（`plugin-toolkit` を利用推奨）
2. `.claude-plugin/marketplace.json` の `plugins[]` にエントリを追加する（`marketplace-toolkit` を利用推奨）
3. **本 README のプラグイン一覧テーブルを同一コミットで更新する**（ADR-019 準拠、`marketplace-toolkit` で自動同期可能）
4. コミット・push して反映する

更新時も同様に、`marketplace.json` の編集と本 README のテーブル更新を **同一コミットで行う** ことを必須とします（ADR-019）。

## 構成

```text
dmajima-claude-plugins/
├── .claude-plugin/
│   └── marketplace.json    # マーケットプレイス定義（プラグイン一覧の正典）
├── README.md               # このファイル（マーケットプレイス README）
└── plugins/                # プラグイン格納先
    └── extension-toolkit/  # 各プラグイン
```

## ライセンス・連絡先

| 項目 | 内容 |
|-----|-----|
| メンテナ | `dmajima` |
| リポジトリ | https://github.com/dmajima/claude-plugins |
