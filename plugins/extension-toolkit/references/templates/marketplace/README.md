# {marketplace-name}

{マーケットプレイスの目的・配布方針を 1〜2 文で記載}

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code が動作中に参照することはありません。マーケットプレイス本体の定義は `.claude-plugin/marketplace.json` にあります。

## プラグイン一覧

| プラグイン | 説明 | バージョン | インストール |
|----------|------|----------|----------|
| `{plugin-name-1}` | {1〜2 文の説明} | {現行 plugin.json の version} | `/plugin install {plugin-name-1}@{marketplace-name}` |
| `{plugin-name-2}` | {1〜2 文の説明} | {現行 plugin.json の version} | `/plugin install {plugin-name-2}@{marketplace-name}` |

各プラグインの詳細は `plugins/{plugin-name}/README.md` を参照してください。

## マーケットプレイスの追加方法

利用者環境に応じて以下のいずれかでマーケットプレイスを Claude Code に登録します。

### A. リモート URL 経由で追加（推奨）

公開リポジトリへのアクセスがある環境向け。

```text
/plugin marketplace add {marketplace-url}
```

### B. ローカル複製で追加（オフライン・企業内環境向け）

公開リポジトリにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone {marketplace-url} <local-path>

# 2. 必要に応じてブランチ・タグ切替（特定リリースを使う場合）
cd <local-path>
git checkout {tag-or-branch}
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>
```

両方式とも、登録後は `/plugin install {plugin-name}@{marketplace-name}` で個別プラグインをインストールできます。

## 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、Claude Code セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "{marketplace-name}": {
      "source": {
        "type": "github",
        "repo": "{owner}/{repo}"
      },
      "autoUpdate": true
    }
  }
}
```

ローカル複製で登録した場合は `source.type` を `"path"` 等に置換してください（環境に応じた設定は Claude Code のドキュメントを参照）。

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

## プラグイン追加手順（メンテナ向け）

1. `plugins/{plugin-name}/` ディレクトリを作成し、プラグインを配置する（`plugin-toolkit` を利用推奨）
2. `.claude-plugin/marketplace.json` の `plugins[]` にエントリを追加する
3. **本 README のプラグイン一覧テーブルを同一コミットで更新する**（ADR-019 準拠）
4. コミット・push して反映する

更新時も同様に、`marketplace.json` の編集と本 README のテーブル更新を **同一コミットで行う** ことを必須とします。

## ライセンス・連絡先

| 項目 | 内容 |
|-----|-----|
| ライセンス | {LICENSE 情報、または該当なし} |
| メンテナ | {`{owner-name}`} |
| 連絡先 | {URL or メール、該当時のみ} |
