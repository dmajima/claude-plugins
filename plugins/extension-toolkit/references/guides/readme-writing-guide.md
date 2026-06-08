# README 記述ガイド（テンプレート・記述例集）

ルール本体は `../policies/readme-policy.md` を参照。本ファイルはテンプレートと記述例を収録する人間向けガイドである。

## 4. 「このドキュメントについて」セクションの定型文

```markdown
## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。
```

スキルなら上記。プラグインなら以下:

```markdown
## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。
```

## 5. 導入手順の書き方

### 5.1 プラグイン（必須 4 要素・ADR-018 準拠）

プラグイン README の「導入手順」には以下を **必ず記載** する。(A) マーケットプレイス経由インストール、(B) ローカル複製インストール、(C) 自動更新の有効化、(D) 依存関係の個別インストール手順。

```markdown
## 導入手順

### 前提

- Claude Code がインストール済み
- {依存プラグインがあれば記載}

### A. マーケットプレイス経由インストール（推奨）

\`\`\`text
/plugin marketplace add {marketplace-url}
/plugin install {plugin-name}@{marketplace-name}
\`\`\`

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録する。

\`\`\`bash
# 1. リポジトリを複製
git clone {repo-url} <local-path>

# 2. 必要に応じてブランチ切替（特定リリースを使う場合）
cd <local-path>
git checkout {tag-or-branch}
\`\`\`

\`\`\`text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install {plugin-name}@{marketplace-name}
\`\`\`

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定する。
これによりセッション起動時にマーケットプレイス + インストール済みプラグインが自動更新される。

\`\`\`json
{
  "extraKnownMarketplaces": {
    "{marketplace-name}": {
      "source": { "...": "..." },
      "autoUpdate": true
    }
  }
}
\`\`\`

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できる。

### D. 依存関係のインストール

`plugin.json` の `dependencies` で宣言された依存プラグインは、利用者のマーケットプレイスで `allowCrossMarketplaceDependenciesOn` が許可されていれば自動インストールされる。
ただし、**依存先マーケットプレイスを利用者が `/plugin marketplace add` で追加していない場合、Claude Code 公式仕様により依存は未解決のまま放置される**（`Dependencies from a marketplace you have not added are left unresolved.`）。
そのため、クロスマーケットプレイス依存（`plugin.json` の `dependencies` に **自プラグインの所属マーケ名と異なる** `marketplace` フィールドが含まれる場合）があるプラグインは、以下 D-1 / D-2 / D-3 の 3 ブロックを **必須記載** する（ADR-028 準拠）。
依存なし・同一マーケ依存のみのプラグインでは、D セクションを「依存関係なし」の 1 行に置き換える（**セクションごとの省略は不可**）。

**D-1. 依存マーケットプレイスの追加（必須）**

\`\`\`text
# 依存マーケットプレイスを追加
/plugin marketplace add {dependency-marketplace-url}
\`\`\`

**D-2. 依存マーケットプレイスの `extraKnownMarketplaces` 登録（必須・自動更新の有効化）**

`~/.claude/settings.json` の `extraKnownMarketplaces` に依存マーケットプレイスを `autoUpdate: true` で登録することで、依存プラグインもセッション起動時に自動更新される。自プラグインのマーケットプレイス登録（C 節）と同形式で並べて示す。

\`\`\`json
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
\`\`\`

**D-3. 依存プラグインの個別インストール（必須）**

\`\`\`text
/plugin install {dependency-plugin-1}@{dependency-marketplace}
/plugin install {dependency-plugin-2}@{dependency-marketplace}
\`\`\`

依存プラグインの一覧は `plugin.json` の `dependencies` フィールドで確認できる。

**Python など外部ツール依存**

スキル内で Python venv や外部 CLI を使う場合、利用者環境にそれらが導入されていることが前提となる。本プラグインの場合の前提:

- Python {version}+（{利用箇所}）
- {その他のツール}

### 動作確認

\`\`\`text
/{command-name} --help
\`\`\`
```

#### 必須 4 要素の省略可否

| 要素 | 省略可否 |
|-----|---------|
| A. マーケットプレイス経由 | **省略不可**（マーケットプレイス未公開でも、公開予定先 URL を `{未公開}` 等で明記） |
| B. ローカル複製 | **省略不可**（公開状況に関係なく、再現可能なクローン手順を必ず記載） |
| C. 自動更新 | **省略不可**（`autoUpdate` が利用できない環境向けの手動更新コマンドも併記） |
| D. 依存関係 | 依存なしのプラグインは「依存関係なし」と **明示**（セクションごと省略は不可）。**クロスマーケットプレイス依存（`plugin.json` の `dependencies` に自マーケ名と異なる `marketplace` フィールド値を含む）の場合は D-1 / D-2 / D-3 の 3 ブロックを全て記載**（ADR-028 準拠） |

### 5.2 スキル

```markdown
## 導入手順

### 前提

- Claude Code がインストール済み
- {依存プラグインがあれば記載}

### 起動方法

以下のフレーズで自動起動します:

- 「{トリガーフレーズ例 1}」
- 「{トリガーフレーズ例 2}」

または `/extension {種別} {対象}` 経由で起動できます。
```

## 6. 利用方法の書き方

### 6.1 最小例（必須）

```markdown
## 利用方法

### 最小例

ユーザ:
> {ユーザの典型的な発話}

Claude（要約）:
> {期待される動作・出力の要約}
```

### 6.2 応用例

```markdown
### 応用例

| 目的 | フレーズ | 動作 |
|-----|---------|------|
| {目的 1} | "{発話}" | {動作} |
| {目的 2} | "{発話}" | {動作} |
```

## 7. 技術スタック・アーキテクチャの記述

**README の後半（セクション 11 推奨位置）** に配置する。利用者がまず知りたいのは「使い方」であり、技術詳細ではない。

```markdown
## 技術スタック・アーキテクチャ

### 内部構成

- 10 スキル + 1 オーケストレータコマンド
- SSOT (`references/`)
- 推奨構成テンプレート (`references/templates/`)

### 採用技術

- Markdown / JSON / YAML
- Python 3.10+（一部スクリプト）
- Claude Code Skills API

### アーキテクチャ判断

詳細は ./references/architecture/ 配下の ADR ファイルを参照。
```

> 上記コードブロック内の「`./references/architecture/` を参照」は、生成 README が記述すべきサンプルテキストです。**実際の README ファイルでは Markdown リンク形式（角括弧でラベルを、丸括弧で URL を指定）で記述してください。** ここでは Markdown リンクとして書くと、本ファイル（README ではなく）から見た broken link として機械チェックで誤検出されるため、平文表記としています。