# extension-toolkit

Claude Code の各種拡張要素（プラグイン・スキル・コマンド・エージェント・チーム・フック）の作成・改修からマーケットプレイス公開までを一気通貫で支援するプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存プラグイン（`plugin.json` の `dependencies` で宣言、自動インストール対象）:
  - `example-skills@anthropic-agent-skills`
  - `document-skills@anthropic-agent-skills`
- `marketplace.json` の `allowCrossMarketplaceDependenciesOn` で `anthropic-agent-skills` 由来プラグインの自動インストールを許可

> **依存の役割**: これらは `skill-toolkit` がスキル雛形・ドキュメント生成系の参考実装を引用する際に利用します。**本プラグインの核機能（スキル/プラグイン/コマンド/エージェント/フック/環境構築/マーケットプレイス管理/レビュー/公開）はこれら依存なしでも動作します**が、利用体験を損なわないよう `dependencies` で宣言し自動解決します（[`references/dependencies-policy.md`](references/dependencies-policy.md) のセクション 4「設定する判断基準」参照）。自動インストールを避けたい場合は、利用者側でマーケットプレイスから個別アンインストールしてください。

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install extension-toolkit@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開リポジトリにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグ（推奨）またはブランチに切替
#    タグを使うと特定バージョンに固定でき、想定外の変更を取り込みません。
cd <local-path>
git checkout v{x.y.z}   # 推奨: 特定リリースタグを指定（最新タグは plugin.json の version、または `git tag --sort=-v:refname | head -1` を参照）
# 厳密な再現性が必要な場合はコミット SHA を直接指定: git checkout <commit-sha>
# タグの GPG 署名検証: git tag -v v{x.y.z}（任意、リリース時に署名されている場合）
# または: git checkout main   # 最新版を追従（注意: 上流の変更を取り込みます）
```

> **企業内環境では特定リリースタグの利用を推奨**: `main` を追従するとリポジトリの将来の変更を取り込みます。社内検証済みの版に固定したい場合はタグ指定 + 自動更新無効化（後述「C. 自動更新の有効化」で `autoUpdate: false`）が安全です。

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install extension-toolkit@dmajima-claude-plugins
```

### C. 自動更新の有効化

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

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

依存プラグイン（`example-skills` / `document-skills`）は、`marketplace.json` の `allowCrossMarketplaceDependenciesOn` で `anthropic-agent-skills` を許可している場合、**自動インストールされます**。
ただし **`anthropic-agent-skills` マーケットプレイスを利用者が `/plugin marketplace add` 済みでない場合、Claude Code 公式仕様により依存は未解決のまま放置されます**（自動マーケ追加機構は存在しません）。
本プラグインはクロスマーケットプレイス依存（自マーケ `dmajima-claude-plugins` と異なる `anthropic-agent-skills` への依存）を持つため、以下 D-1 / D-2 / D-3 の 3 ブロックを **必須実施** としています（ADR-028 準拠）。

**D-1. 依存マーケットプレイスの追加（必須）**

```text
/plugin marketplace add https://github.com/anthropics/skills
```

**D-2. 依存マーケットプレイスの自動更新有効化（必須）**

`~/.claude/settings.json` の `extraKnownMarketplaces` に依存マーケットプレイスを `autoUpdate: true` で登録します。これにより依存プラグインもセッション起動時に自動更新されます。自プラグインの `dmajima-claude-plugins` 登録（C 節）と並べて記述します。

```json
{
  "extraKnownMarketplaces": {
    "anthropic-agent-skills": {
      "source": {
        "type": "github",
        "repo": "anthropics/skills"
      },
      "autoUpdate": true
    }
  }
}
```

**D-3. 依存プラグインの個別インストール（必須）**

```text
/plugin install example-skills@anthropic-agent-skills
/plugin install document-skills@anthropic-agent-skills
```

#### Python 等の外部ツール依存

一部スキル（`environment-setup-toolkit`）で Python venv を構築する場合、利用者環境に Python が導入されていることが前提となります:

- Python 3.10 以上
- 標準ライブラリ `venv` モジュール（通常 Python に同梱）
- `git`（ローカル複製インストール時）

### 動作確認

```text
/extension
```

引数なしで呼び出すと対話モードで起動対象を確認します。

## 利用方法

### スラッシュコマンド

```text
/extension <種別> [<引数>]
```

種別:

| 種別 | 起動スキル | 用途例 |
|-----|----------|-------|
| `skill <name>` | `skill-toolkit` | スキル新規作成・改修 |
| `plugin <name>` | `plugin-toolkit` | プラグイン外形作成・既存資産移管 |
| `command <name>` | `command-toolkit` | スラッシュコマンド作成・改修 |
| `agent <name>` | `agent-toolkit` | サブエージェント単体作成 |
| `team <name>` | `agent-toolkit`（チームモード） | エージェントチーム編成 |
| `hook <event>` | `hook-toolkit` | フック設定作成 |
| `readme <target>` | `readme-toolkit` | プラグイン・スキル README 生成・更新 |
| `setup <work-dir>` | `environment-setup-toolkit` | Python venv 構築 |
| `marketplace <name>` | `marketplace-toolkit` | マーケットプレイス新規構築・本体管理 |
| `license <plugin>` | `mit-license-toolkit` | MIT LICENSE 配備・`plugin.json.license` 設定（ADR-029） |
| `review <target>` | `extension-reviewer` | 多角レビュー |
| `publish <plugin>` | `marketplace-publisher` | プラグイン公開ワークフロー |

### 自然言語起動

| 発話例 | 起動スキル |
|-------|----------|
| 「新しいスキル `foo` を作って」 | `skill-toolkit` |
| 「`bar` プラグインを作成」 | `plugin-toolkit` |
| 「`/baz` コマンドを作って」 | `command-toolkit` |
| 「コードレビュー用エージェントチームを設計」 | `agent-toolkit` |
| 「PreToolUse フックで X したい」 | `hook-toolkit` |
| 「`qux` スキルの README を書いて」 | `readme-toolkit` |
| 「Python venv 作って」 | `environment-setup-toolkit` |
| 「新しいマーケットプレイス `acme-claude-plugins` を作って」 | `marketplace-toolkit` |
| 「`grault` プラグインに MIT ライセンスを追加」 | `mit-license-toolkit` |
| 「`quux` プラグインをレビュー」 | `extension-reviewer` |
| 「`corge` プラグインを公開」 | `marketplace-publisher` |

### 最小例

ユーザ:
> 新しいプラグイン `dev-toolkit` を作って、`code-formatter` スキルも含めて

Claude（要約）:
> `plugin-toolkit` で外形作成 → `skill-toolkit` で `code-formatter` 雛形 →
> `extension-reviewer` でレビュー → `marketplace-publisher` で公開ハンドオフ。
> 各ステップで AskUserQuestion による選択 UI で意思確認します。

## 動作要件

| 項目 | 要件 |
|-----|------|
| Claude Code | 最新版推奨 |
| Python（一部スキルで venv 利用時） | 3.10+ |
| 依存プラグイン（自動インストール） | `example-skills` / `document-skills`（`anthropic-agent-skills` マーケットプレイス、`plugin.json` の `dependencies` で宣言） |

## 提供スキル一覧

| スキル | 担当 |
|-------|------|
| `skill-toolkit` | スキル新規作成・改修 |
| `plugin-toolkit` | プラグイン外形作成・既存資産移管 |
| `command-toolkit` | スラッシュコマンド作成・改修 |
| `agent-toolkit` | サブエージェント・エージェントチーム作成 |
| `hook-toolkit` | フック設定作成 |
| `readme-toolkit` | プラグイン・スキル単位の README 生成・更新 |
| `environment-setup-toolkit` | Python venv 等の環境構築・撤去 |
| `marketplace-toolkit` | マーケットプレイス新規構築・本体管理（`marketplace.json` + マーケットプレイス README） |
| `mit-license-toolkit` | MIT LICENSE 配備・`plugin.json.license` 設定・`license-info.json` 管理（ADR-029） |
| `extension-reviewer` | 拡張要素の多角レビュー（チーム起動） |
| `marketplace-publisher` | プラグイン公開ワークフロー（git push / PR、`marketplace.json` 編集は `marketplace-toolkit` に委譲） |

## 同梱フック（v1.2.0+, ADR-026）

本プラグインは 2 種類のフックを同梱します。**ハードブロック型ではなく警告型** に設計されており、軽微な編集体験を妨げず、真の問題（バージョン更新漏れ）には Stop フックで直接対処します。

| フック | タイミング | 動作 | 目的 |
|-----|---------|-----|-----|
| **PreToolUse Edit/Write/MultiEdit** | 編集直前 | exit 0 + stderr に推奨スキル名提示（**ブロックしない**） | Claude の自律判断材料、新規・大規模変更時に適切な `*-toolkit` を選択させる |
| **Stop** | Claude のターン終了時 | `plugins/{name}/` の未コミット変更があり `plugin.json` の version が main から未更新の場合に stderr で警告（fail-open） | バージョン更新漏れの直接的な検出（コミット前に気付ける） |

| 配置 | 内容 |
|-----|-----|
| `hooks/hooks.json` | フック設定（`PreToolUse Edit\|Write\|MultiEdit` + `PreToolUse Bash`（git commit 検出）+ `Stop`）。各 hook は `"shell": "powershell"` を明示 |
| `references/scripts/hooks/enforce_toolkit_routing.ps1` | PreToolUse Edit\|Write\|MultiEdit: 推奨スキル名の提示 |
| `references/scripts/hooks/check_version_bump_on_commit.ps1` | PreToolUse Bash: `git commit` 検出時に check_version_bump.ps1 に委譲（ADR-027） |
| `references/scripts/hooks/check_version_bump.ps1` | Stop: version 更新検証 |
| 除外パス | `.claude/.local/` / `.git/` / `/tmp/` 配下、git 利用不可環境、リポジトリ外 |

「軽微な編集（typo・1〜数行修正）は直接編集 OK / 新規・大規模変更時は toolkit 経由」という運用バランスを取り、コミット前に必ずバージョン更新が促される設計です。詳細は [`references/architecture-decisions.md`](references/architecture-decisions.md) ADR-026 を参照。

## エージェント・チーム

プラグイン同梱の専門家エージェント（`agents/`）:

| ID | 担当観点 |
|----|---------|
| `plugin-structure-reviewer` | 規約準拠 |
| `evals-coverage-reviewer` | evals 網羅性 |
| `description-trigger-reviewer` | description のトリガー精度 |
| `marketplace-fit-reviewer` | マーケットプレイス適合 |

レビューチーム（`references/teams/`、ADR-002 / ADR-003 準拠）:

| チーム | 用途 | リード |
|-------|-----|-------|
| `plugin-review-team` | プラグイン横断 | `architect` |
| `skill-review-team` | スキル単体 | `plugin-structure-reviewer` |
| `hook-security-team` | フック安全性 | `security-engineer` |

## カスタマイズ・拡張

| やりたいこと | 編集対象 |
|------------|---------|
| 命名・配置規約 | `references/conventions.md` |
| AI 誤認回避ルール | `references/ai-readability.md` |
| description 設計 | `references/description-guide.md` |
| ポータブルパス規約 | `references/path-portability.md` |
| evals 設計 | `references/eval-guide.md` |
| 検証ルール | `references/validation-rules.md` |
| バージョン管理 | `references/versioning.md` |
| 完了チェックリスト | `references/completion-checklist.md` |
| Claude UI 利用ルール | `references/user-interaction.md` |
| 状態ファイル形式 | `references/state-files.md` |
| README 規約（プラグイン・スキル・マーケットプレイス共通） | `references/readme-policy.md` |
| ライセンスポリシー（MIT 必須化） | `references/license-policy.md` |
| エージェント活用方針 | `references/agent-utilization.md` |
| レビューフレッシュ起動原則（ADR-021） | `references/review-freshness.md` |
| プラグイン自己完結性・利用者環境非依存（ADR-022） | `references/self-containment.md` |
| 依存関係宣言ルール | `references/dependencies-policy.md` |
| 推奨構成テンプレート | `references/templates/{種別}/` |
| エージェントチーム定義 | `references/teams/{name}.md` |
| 新拡張要素対応 | `skills/` 配下に新スキル追加、`references/conventions.md` 追記、`/extension` ルーティング追加 |

## 関連リンク

- マーケットプレイス: `dmajima-claude-plugins`
- 公式仕様: https://code.claude.com/docs/en/plugins-reference.md
- 依存プラグイン仕様: https://code.claude.com/docs/en/plugin-dependencies.md

## ファイル構成

```text
plugins/extension-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE                          # MIT ライセンス（ADR-029）
├── commands/
│   └── extension.md                 # /extension オーケストレータ
├── references/                      # SSOT（プラグイン横断の共通ナレッジ）
│   ├── conventions.md               # 命名・配置・構造規約
│   ├── ai-readability.md
│   ├── description-guide.md
│   ├── path-portability.md
│   ├── eval-guide.md
│   ├── validation-rules.md
│   ├── architecture-decisions.md
│   ├── versioning.md
│   ├── completion-checklist.md
│   ├── user-interaction.md
│   ├── state-files.md
│   ├── readme-policy.md
│   ├── license-policy.md            # ライセンスポリシー（MIT 必須化、ADR-029）
│   ├── agent-utilization.md
│   ├── review-freshness.md          # レビューフレッシュ起動原則（ADR-021）
│   ├── self-containment.md          # プラグイン自己完結性（ADR-022）
│   ├── dependencies-policy.md
│   ├── teams/                       # エージェントチーム定義
│   │   ├── plugin-review-team.md
│   │   ├── skill-review-team.md
│   │   └── hook-security-team.md
│   └── templates/                   # 推奨構成テンプレート
│       ├── skill/
│       ├── plugin/                  # plugin.json + README + LICENSE テンプレート
│       ├── command/
│       ├── agent/
│       ├── hook/
│       ├── readme/
│       └── marketplace/
├── agents/                          # プラグイン同梱エージェント（Claude Code 公式仕様）
│   ├── plugin-structure-reviewer.md
│   ├── evals-coverage-reviewer.md
│   ├── description-trigger-reviewer.md
│   └── marketplace-fit-reviewer.md
└── skills/
    ├── skill-toolkit/
    ├── plugin-toolkit/
    ├── command-toolkit/
    ├── agent-toolkit/
    ├── hook-toolkit/
    ├── readme-toolkit/
    ├── environment-setup-toolkit/
    ├── marketplace-toolkit/
    ├── mit-license-toolkit/         # MIT LICENSE 配備・license-info.json 管理（ADR-029）
    ├── extension-reviewer/
    └── marketplace-publisher/
```

## 技術スタック・アーキテクチャ

### 採用技術

- Markdown / JSON / YAML
- Python 3.10+（一部スクリプト：プラグイン直下 `references/scripts/setup/`、ADR-024）
- Bash（クロスプラットフォーム対応：Windows `Scripts/` / Unix `bin/`）
- Claude Code Plugins / Skills / Agents API

### 設計原則

- **責務単一（1 スキル 1 責務）** — 各スキルは責務外を他スキルに委譲
- **SSOT** — 共通ナレッジはプラグイン直下の `references/` に集約
- **テンプレート明示管理** — 推奨構成は `references/templates/` で一元管理（生成物のムラ防止）
- **AI 誤認回避優先** — SKILL.md / references は AI が誤読しない断定表現を優先
- **対話/非対話モード両対応** — 各スキルに `--non-interactive` モードあり
- **動作分岐は evals 必須** — 条件分岐ありのスキルは `evals/` で期待動作を例示
- **トークン効率** — SKILL.md 200 行以内、詳細は `references/` に分離
- **AskUserQuestion 優先** — ユーザ選択は Claude UI で実施
- **作業完了前自己検証** — チェックリスト運用を全スキルに義務化

### アーキテクチャ判断

詳細は [`references/architecture-decisions.md`](references/architecture-decisions.md) を参照（全 ADR）。

## ライセンス

[MIT License](LICENSE) の下で配布されています。
