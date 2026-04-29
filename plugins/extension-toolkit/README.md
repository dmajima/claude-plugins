# extension-toolkit

Claude Code の各種拡張要素（プラグイン・スキル・コマンド・エージェント・チーム・フック）を作成し、マーケットプレイスへ公開するまでを一気通貫で支援するプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は各スキルの `SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| スキル | 担当 |
|-------|------|
| `skill-toolkit` | スキルの新規作成・既存改修。`example-skills@anthropic-agent-skills` / `document-skills@anthropic-agent-skills` と連携 |
| `plugin-toolkit` | プラグインの新規作成・既存資産のプラグイン構造化 |
| `command-toolkit` | スラッシュコマンドの作成 |
| `agent-toolkit` | サブエージェント・エージェントチームの設計・作成 |
| `hook-toolkit` | フック設定の作成 |
| `readme-toolkit` | README（人間向けリファレンス）の生成・更新 |
| `extension-reviewer` | 拡張要素（スキル/プラグイン/エージェント）の横断レビュー |
| `marketplace-publisher` | マーケットプレイスへの公開・重複チェック・マージ提案 |

## オーケストレータ

```text
/extension <作成対象> [<引数>]
```

例:

```text
/extension skill code-formatter
/extension plugin dev-toolkit
/extension review skills/foo-skill
/extension publish dev-toolkit
```

`/extension` は対象に応じて適切なスキルへバトンを渡すオーケストレータです。

## 自然言語での起動

| 発話例 | 起動スキル |
|-------|-----------|
| 「新しいスキル `foo` を作って」 | `skill-toolkit` |
| 「`bar` プラグインを作成」 | `plugin-toolkit` |
| 「`/baz` コマンドを作って」 | `command-toolkit` |
| 「コードレビュー用エージェントチームを設計」 | `agent-toolkit` |
| 「PreToolUse フックで X したい」 | `hook-toolkit` |
| 「`qux` スキルの README を書いて」 | `readme-toolkit` |
| 「`quux` プラグインをレビュー」 | `extension-reviewer` |
| 「`corge` プラグインを公開」 | `marketplace-publisher` |

## 設計原則

- **責務単一（1スキル1責務）** — 各スキルは自分の責務外を他スキルに委ねる
- **SSOT** — 共通ナレッジはプラグイン直下の `references/` に集約、各スキルは参照のみ
- **テンプレート化** — 推奨構成は `templates/` に明示管理（生成物のムラ防止）
- **AI 誤認回避優先** — SKILL.md / references は人間可読性より AI が誤読しない断定的・条件表ベースの表現を優先
- **対話/非対話モード両対応** — 各スキルのプロンプトに分岐ルートを明示
- **動作分岐は evals 必須** — 条件分岐ありのスキルは `evals/` で期待動作を例示
- **トークン効率** — SKILL.md 200 行以内、詳細は `references/` に分離

## ファイル構成

```text
plugins/extension-toolkit/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/
│   └── extension.md                 # /extension オーケストレータ
├── references/                      # SSOT（プラグイン横断の共通ナレッジ）
│   ├── conventions.md               # 命名・配置・構造規約
│   ├── ai-readability.md            # AI 誤認回避ライティング規約
│   ├── description-guide.md         # description 設計ガイド
│   ├── path-portability.md          # ポータブルパス規約
│   └── eval-guide.md                # evals 作成ガイド
├── templates/                       # 推奨構成テンプレート
│   ├── skill/
│   ├── plugin/
│   ├── command/
│   ├── agent/
│   ├── hook/
│   └── readme/
└── skills/
    ├── skill-toolkit/
    ├── plugin-toolkit/
    ├── command-toolkit/
    ├── agent-toolkit/
    ├── hook-toolkit/
    ├── readme-toolkit/
    ├── extension-reviewer/
    └── marketplace-publisher/
```

## 依存プラグイン（外部知識参照）

`skill-toolkit` は以下のスキルを `Skill` ツール経由で利用する場合があります:

| 依存先 | 用途 |
|-------|------|
| `example-skills@anthropic-agent-skills` | スキル雛形・ベストプラクティス参照 |
| `document-skills@anthropic-agent-skills` | ドキュメント生成系スキル参照 |

利用前にユーザのマーケットプレイスに該当プラグインがインストール済みか確認します。

## 拡張・カスタマイズ

| やりたいこと | 編集対象 |
|------------|---------|
| 命名規約・配置規約の変更 | `references/conventions.md` |
| 推奨構成（テンプレート）の変更 | `templates/{種別}/` |
| トリガー文言・description の方針変更 | `references/description-guide.md` |
| 新しい拡張要素（例: MCP）対応 | `skills/` 配下に新スキル追加、`references/conventions.md` 追記、`/extension` ルーティング追加 |

## 利用方法

`dmajima-claude-plugins` マーケットプレイス経由で配布されます。インストール:

```text
/plugin install extension-toolkit@dmajima-claude-plugins
```
