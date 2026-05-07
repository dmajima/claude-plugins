# README 規約（SSOT）

プラグイン・スキル等の `README.md`（人間向けリファレンス）の規約。

## 1. 必須化

`extension-toolkit` が生成・改修する **すべてのプラグイン・スキル** に `README.md` を必ず作成する。`README.md` は省略不可。

## 2. README の役割

| 役割 | 内容 |
|-----|------|
| **対象読者** | 人間（利用者・開発者） |
| **Claude が動作中に参照** | しない |
| **保管期間** | 常に最新版のみ（過去履歴は Git で管理、README に残さない、ADR-016 準拠） |

## 3. 必須セクションと優先順位

README は **利用者の知りたい順** にセクションを並べる。

| 順序 | セクション | 必須 | 内容 |
|-----|----------|------|------|
| 1 | タイトル | 必須 | プラグイン名 / スキル名 |
| 2 | 概要（1〜3 文） | 必須 | 何ができるか |
| 3 | このドキュメントについて | 必須 | 「人間向けリファレンス・Claude 動作で不参照」明記 |
| 4 | **導入手順（インストール）** | 必須 | プラグインなら `/plugin install`、スキルならトリガー |
| 5 | **利用方法（基本）** | 必須 | スラッシュコマンド・自然言語フレーズ・最小例 |
| 6 | 利用方法（応用） | 推奨 | 高度な機能・組み合わせ例 |
| 7 | 動作要件 | 必須（該当時） | 依存プラグイン・依存ツール・OS |
| 8 | カスタマイズ | 推奨 | 拡張・変更ポイント |
| 9 | ファイル構成 | 推奨 | ディレクトリツリー |
| 10 | 関連スキル / 関連リンク | 推奨 | 関連リソース |
| 11 | **技術スタック・アーキテクチャ** | 任意 | 内部設計・採用技術（後半に配置） |
| 12 | ライセンス | 該当時 | LICENSE への参照 |

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

詳細は ./references/architecture-decisions.md を参照。
```

> 上記コードブロック内の「`./references/architecture-decisions.md` を参照」は、生成 README が記述すべきサンプルテキストです。**実際の README ファイルでは Markdown リンク形式（角括弧でラベル `references/architecture-decisions.md` を、丸括弧で URL `references/architecture-decisions.md` を指定）で記述してください。** ここでは Markdown リンクとして書くと、本ファイル（README ではなく）から見た broken link として機械チェックで誤検出されるため、平文表記としています。

## 8. 過去履歴記載の禁止

| 禁止 | 代替 |
|-----|------|
| 「## 変更履歴」「## Changelog」 | Git コミット履歴 |
| 「v0.1 で追加」「v0.2 で変更」 | Git タグ・コミットメッセージ |
| 「以前は ~~deprecated~~」 | 削除（コードから消す） |
| 「廃止予定」 | 削除予定なら直接削除、保留なら別ドキュメント |

## 9. 絵文字・装飾

| 観点 | 推奨 |
|-----|------|
| 絵文字 | ユーザ明示指示なき限り **使用しない** |
| 太字・斜体 | 強調が必要な場合のみ |
| 表 | 構造化情報には積極利用 |
| 見出しレベル | h1（タイトル） → h2 → h3 まで（h4 以下は避ける） |

## 10. 検証

README 作成・更新後に以下を確認:

- [ ] タイトル + 概要が冒頭にある
- [ ] 「このドキュメントについて」セクションあり
- [ ] 導入手順がセクション 4 位に存在
- [ ] **プラグイン: 導入手順に 4 要素（A マーケットプレイス / B ローカル複製 / C 自動更新 / D 依存関係）が網羅されている**（ADR-018 準拠）
- [ ] **プラグイン（クロスマーケットプレイス依存あり）: D セクションに D-1（マーケ add）/ D-2（`extraKnownMarketplaces` 登録）/ D-3（プラグイン install）の 3 ブロックが揃っている**（ADR-028 準拠）
- [ ] 利用方法（最小例）がある
- [ ] 技術スタック・アーキテクチャは後半に配置されている
- [ ] 過去履歴・変更経緯の記載なし
- [ ] 絵文字なし（指示なき限り）
- [ ] プレースホルダ `{...}` 残存なし
- [ ] パスポータビリティ合格

## 11. README 作成は readme-toolkit が担当

`README.md` の生成・更新は `readme-toolkit` スキルが担当する。他の `*-toolkit` スキルが本体を作った後、`readme-toolkit` を呼んで README を生成する流れ。

## 11.1 マーケットプレイス直下 README の同期義務（ADR-019 準拠）

プラグインを **追加・更新・削除** する際は、`marketplace.json` の更新と **同一コミット** でマーケットプレイス直下の `README.md`（リポジトリルート README）を更新する。

### 必須セクション

| 順序 | セクション | 必須 | 内容 |
|-----|----------|------|------|
| 1 | タイトル | 必須 | マーケットプレイス名 |
| 2 | 概要 | 必須 | このマーケットプレイスの目的・配布方針 |
| 3 | プラグイン一覧 | **必須** | 名前 / 説明 / 現行バージョン / インストールコマンドのテーブル |
| 4 | 利用方法（マーケットプレイス登録） | **必須** | A: URL 経由 + B: ローカル複製の両方 |
| 5 | 自動更新の有効化 | **必須** | `extraKnownMarketplaces` の `autoUpdate: true` 設定例 |
| 6 | 依存マーケットプレイス | 条件付き必須（`allowCrossMarketplaceDependenciesOn` 非空時に必須） | 依存先名・用途・個別追加コマンド |
| 7 | プラグイン追加手順（メンテナ向け） | 推奨 | リポジトリ構成・新規プラグイン追加フロー |
| 8 | ライセンス・連絡先 | 該当時 | LICENSE / 連絡先 |

### プラグイン一覧テーブルの形式

```markdown
## プラグイン一覧

| プラグイン | 説明 | バージョン | インストール |
|----------|------|----------|----------|
| `{plugin-name-1}` | {1〜2 文の説明} | {現行 plugin.json の version} | `/plugin install {plugin-name-1}@{marketplace-name}` |
| `{plugin-name-2}` | ... | ... | ... |
```

バージョンは各プラグインの `plugin.json` から **直接転記** する（`marketplace.json` 側にバージョン情報は持たない）。

### 同期トリガー

| トリガー | README 更新内容 |
|---------|---------------|
| プラグイン新規追加 | プラグイン一覧に行追加、必要なら関連セクションを追記 |
| プラグイン更新（バージョン変更含む） | バージョン列・説明列を最新化 |
| プラグイン削除 | 該当行を削除、関連リンクを除去 |
| マーケットプレイス自体の方針変更 | 概要・利用方法を更新 |

### 担当

- 通常は **`marketplace-toolkit` が `marketplace.json` 編集と同期で本 README を更新する**（ADR-020 準拠、[`../skills/marketplace-toolkit/references/readme-sync.md`](../skills/marketplace-toolkit/references/readme-sync.md) のロジックに従う）。`marketplace-publisher` はプラグイン公開フロー内で `marketplace-toolkit` を Skill ツール経由で呼び出して同期させる（[`../skills/marketplace-publisher/references/publish-workflow.md`](../skills/marketplace-publisher/references/publish-workflow.md)）
- ハンドオフモードの場合は、ハンドオフ手順書に「マーケットプレイス README 更新」を **必ず含める**
- `marketplace.json` のみを変更してマーケットプレイス README を放置するコミットは ADR-019 違反として禁止

## 12. 禁止事項

- README の省略
- 過去履歴・変更経緯の記載
- 技術スタック・アーキテクチャを冒頭に配置
- 「このドキュメントについて」セクションの省略
- AI 動作で参照される前提の記述（README は人間向け）
- **プラグイン README で導入手順 4 要素（A/B/C/D）のいずれかを欠落させること**（ADR-018 違反）
- **依存関係を持つプラグインで個別インストール手順を省略すること**（自動解決前提の記述のみは不可）
- **クロスマーケットプレイス依存ありのプラグインで `extraKnownMarketplaces` 登録テンプレート（D-2）を省略すること**（ADR-028 違反、自動更新ポリシーと不整合）
