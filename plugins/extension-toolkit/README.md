# extension-toolkit

Claude Code の各種拡張要素（プラグイン・スキル・コマンド・エージェント・チーム・フック）の作成・改修からマーケットプレイス公開までを一気通貫で支援するプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- 推奨依存プラグイン: `example-skills@anthropic-agent-skills` / `document-skills@anthropic-agent-skills`（自動インストール対象、`marketplace.json` の `allowCrossMarketplaceDependenciesOn` で許可済）

### インストール

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install extension-toolkit@dmajima-claude-plugins
```

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
| `readme <target>` | `readme-toolkit` | README 生成・更新 |
| `setup <work-dir>` | `environment-setup-toolkit` | Python venv 構築 |
| `review <target>` | `extension-reviewer` | 多角レビュー |
| `publish <plugin>` | `marketplace-publisher` | マーケットプレイス公開 |

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
| 推奨依存プラグイン | `example-skills` / `document-skills`（`anthropic-agent-skills` マーケットプレイス） |

## 提供スキル一覧

| スキル | 担当 |
|-------|------|
| `skill-toolkit` | スキル新規作成・改修 |
| `plugin-toolkit` | プラグイン外形作成・既存資産移管 |
| `command-toolkit` | スラッシュコマンド作成・改修 |
| `agent-toolkit` | サブエージェント・エージェントチーム作成 |
| `hook-toolkit` | フック設定作成 |
| `readme-toolkit` | README 生成・更新 |
| `environment-setup-toolkit` | Python venv 等の環境構築・撤去 |
| `extension-reviewer` | 拡張要素の多角レビュー（チーム起動） |
| `marketplace-publisher` | マーケットプレイス公開・重複/マージチェック |

## エージェント・チーム

プラグイン同梱の専門家エージェント（`agents/`）:

| ID | 担当観点 |
|----|---------|
| `plugin-structure-reviewer` | 規約準拠 |
| `evals-coverage-reviewer` | evals 網羅性 |
| `description-trigger-reviewer` | description のトリガー精度 |
| `marketplace-fit-reviewer` | マーケットプレイス適合 |

レビューチーム（`teams/`）:

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
| README 規約 | `references/readme-policy.md` |
| エージェント活用方針 | `references/agent-utilization.md` |
| 依存関係宣言ルール | `references/dependencies-policy.md` |
| 推奨構成テンプレート | `templates/{種別}/` |
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
├── commands/
│   └── extension.md                 # /extension オーケストレータ
├── references/                      # SSOT（プラグイン横断の共通ナレッジ）
│   ├── conventions.md
│   ├── ai-readability.md
│   ├── description-guide.md
│   ├── path-portability.md
│   ├── eval-guide.md
│   ├── validation-rules.md
│   ├── architecture-decisions.md
│   ├── versioning.md                # 追加要件: バージョン管理
│   ├── completion-checklist.md      # 追加要件: 作業完了前チェック
│   ├── user-interaction.md          # 追加要件: AskUserQuestion 優先
│   ├── state-files.md               # 追加要件: 状態ファイル形式
│   ├── readme-policy.md             # 追加要件: README 規約
│   ├── agent-utilization.md         # 追加要件: エージェント活用
│   └── dependencies-policy.md       # 追加要件: 依存関係宣言
├── templates/                       # 推奨構成テンプレート
│   ├── skill/
│   ├── plugin/
│   ├── command/
│   ├── agent/
│   ├── hook/
│   └── readme/
├── agents/                          # プラグイン同梱エージェント
│   ├── plugin-structure-reviewer.md
│   ├── evals-coverage-reviewer.md
│   ├── description-trigger-reviewer.md
│   └── marketplace-fit-reviewer.md
├── teams/                           # エージェントチーム定義
│   ├── plugin-review-team.md
│   ├── skill-review-team.md
│   └── hook-security-team.md
└── skills/
    ├── skill-toolkit/
    ├── plugin-toolkit/
    ├── command-toolkit/
    ├── agent-toolkit/
    ├── hook-toolkit/
    ├── readme-toolkit/
    ├── environment-setup-toolkit/
    ├── extension-reviewer/
    └── marketplace-publisher/
```

## 技術スタック・アーキテクチャ

### 採用技術

- Markdown / JSON / YAML
- Python 3.10+（一部スクリプト：`environment-setup-toolkit/scripts/python/`）
- Bash（クロスプラットフォーム対応：Windows `Scripts/` / Unix `bin/`）
- Claude Code Plugins / Skills / Agents API

### 設計原則

- **責務単一（1 スキル 1 責務）** — 各スキルは責務外を他スキルに委譲
- **SSOT** — 共通ナレッジはプラグイン直下の `references/` に集約
- **テンプレート明示管理** — 推奨構成は `templates/` で一元管理（生成物のムラ防止）
- **AI 誤認回避優先** — SKILL.md / references は AI が誤読しない断定表現を優先
- **対話/非対話モード両対応** — 各スキルに `--non-interactive` モードあり
- **動作分岐は evals 必須** — 条件分岐ありのスキルは `evals/` で期待動作を例示
- **トークン効率** — SKILL.md 200 行以内、詳細は `references/` に分離
- **AskUserQuestion 優先** — ユーザ選択は Claude UI で実施
- **作業完了前自己検証** — チェックリスト運用を全スキルに義務化

### アーキテクチャ判断

詳細は [`references/architecture-decisions.md`](references/architecture-decisions.md) を参照（ADR-001〜008）。
