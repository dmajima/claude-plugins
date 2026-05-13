# dmajima-claude-plugins

dmajima 個人用 Claude Code プラグインマーケットプレイス。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code が動作中に参照することはありません。マーケットプレイス本体の定義は `.claude-plugin/marketplace.json` にあります。

## プラグイン一覧

各プラグインの詳細は `plugins/{plugin-name}/README.md` を参照してください。

| プラグイン | 説明 | バージョン | インストール |
|----------|------|----------|----------|
| `credentials-manager` | Claude Code セッションをまたいで認証情報を保存・自動適用するプラグイン（URL/ドメイン自動マッチ + SessionStart で最重要ルール自動配置 + UserPromptSubmit/PreToolUse で外部通信・認証情報系ファイル・シークレット直接埋め込みを多層検出） | 1.1.2 | `/plugin install credentials-manager@dmajima-claude-plugins` |
| `extension-toolkit` | Claude Code 拡張要素（プラグイン/スキル/コマンド/エージェント/フック）の作成・レビュー・公開を統括支援 | 1.8.0 | `/plugin install extension-toolkit@dmajima-claude-plugins` |
| `plugins-update` | インストール済みマーケットプレイス・プラグインを公式 CLI で一括最新化する | 1.1.1 | `/plugin install plugins-update@dmajima-claude-plugins` |
| `convert-doc` | Markdown と HTML / PDF / PowerPoint（PPTX）を相互変換できる 4 スキル + 5 コマンド同梱のドキュメント変換プラグイン（PPTX → Markdown は機械抽出 + LLM 意味解釈 + カバレッジ検証の 3 フェーズ構成、大規模 PPTX 分割対応） | 3.1.0 | `/plugin install convert-doc@dmajima-claude-plugins` |
| `skill-router` | プロンプト送信時に available-skills を自動スコアリングしてフック注入で適合スキルを推奨。ロジック編集は対象外 | 0.4.5 | `/plugin install skill-router@dmajima-claude-plugins` |
| `session-usage` | カレントセッションのトークン消費量を JSONL から直接集計し、AskUserQuestion 対話メニュー（プレビュー表示・クリップボードコピー・再集計）で操作できる完全内製プラグイン | 1.0.0 | `/plugin install session-usage@dmajima-claude-plugins` |

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

依存マーケットプレイスは `allowCrossMarketplaceDependenciesOn` で許可されていても、**利用者が `/plugin marketplace add` 済みでなければ Claude Code 公式仕様により依存は未解決のまま放置されます**（自動マーケ追加機構なし）。詳細は ADR-028（[`plugins/extension-toolkit/references/architecture-decisions.md`](plugins/extension-toolkit/references/architecture-decisions.md)）参照。

### 依存マーケットプレイスの自動更新有効化（推奨）

依存マーケットプレイスの `extraKnownMarketplaces` 登録（`autoUpdate: true`）も併せて行うと、依存先プラグインもセッション起動時に自動更新されます。本マーケットプレイス自身の登録（前述「自動更新の有効化」節）と並べて記述します。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": { "type": "github", "repo": "dmajima/claude-plugins" },
      "autoUpdate": true
    },
    "anthropic-agent-skills": {
      "source": { "type": "github", "repo": "anthropics/skills" },
      "autoUpdate": true
    }
  }
}
```

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
    ├── convert-doc/
    ├── credentials-manager/
    ├── extension-toolkit/
    ├── plugins-update/
    ├── session-usage/
    └── skill-router/
```

## ライセンス・連絡先

| 項目 | 内容 |
|-----|-----|
| メンテナ | `dmajima` |
| リポジトリ | https://github.com/dmajima/claude-plugins |
