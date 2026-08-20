# project-harness

対象プロジェクトに AI エージェントの足場となる `.claude` ハーネス（`CLAUDE.md` + `references/` 配下の仕様・設計・検証環境ドキュメント体系）を初期構築し、開発・修正で生じたコード変更を随時ドキュメントへ同期する環境整備プラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `harness-init` | スキル | プロジェクトを解析（サブエージェント並列調査）して `.claude` ハーネスを初期構築し、`.sync-state.json` を初期化 |
| `harness-update` | スキル | 最終同期コミットと HEAD の差分から影響ドキュメントを特定し、記載・索引・同期状態を最新化 |
| `/project-harness:init` | コマンド | `harness-init` への薄いラッパー |
| `/project-harness:update` | コマンド | `harness-update` への薄いラッパー |
| 鮮度検知フック | フック（SessionStart） | 最終同期からの乖離コミット数が閾値（既定 10）以上のとき `/project-harness:update` の実行を推奨通知 |

## 構築されるハーネス構成

対象プロジェクトに以下が生成されます（詳細仕様は `references/structure-spec.md`）:

```text
<target-repo>/.claude/
├── CLAUDE.md                  # プロジェクト概要・技術スタック（常時読込・100 行以内）
└── references/
    ├── CLAUDE.md              # ドキュメント索引・整理ルール
    ├── .sync-state.json       # 同期状態（最終同期コミット・閾値）
    ├── specs/                 # 仕様設計書（画面遷移・画面構成・業務ルール・アプリ動作）
    ├── system-designs/        # 詳細設計書（specs 対応・実装で詳細化すべき設計情報）
    ├── flows/                 # 画面位置・アクセス手順
    ├── environments/          # ビルド・テスト・起動・検証コマンド（検証ハーネス）
    ├── conventions/           # コーディング規約・命名・配置・コミット/PR 規約
    ├── architecture/          # システム構成・モジュール依存・データモデル
    ├── decisions/             # ADR（設計判断記録）
    └── glossary.md            # ドメイン用語集
```

各ドキュメントは frontmatter の `sources`（対応ソースパスのグロブ）を持ち、`harness-update` が git 差分と照合して影響ドキュメントだけを更新します。

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存プラグインなし

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install project-harness@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins.git <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install project-harness@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

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

依存関係なし。

**Python 等の外部ツール依存**

- git 2.30+（同期基準にコミット SHA を使用するため必須）

### 動作確認

インストール後に Claude Code を再起動し、`/project-harness:` まで入力して `init` / `update` が補完候補に表示されることを確認します。

## 使い方

### 初期構築

対象プロジェクト（git リポジトリ）で実行します:

```text
/project-harness:init
```

1. 既存資産（ルート CLAUDE.md・README・docs/）の取り込み方針を確認
2. サブエージェントがプロジェクトを並列調査（技術スタック / 機能・画面 / アーキテクチャ / 規約・用語）
3. 生成範囲（全機能 / 主要機能のみ / 個別選択）を選択
4. ハーネス一式が生成され、`.sync-state.json` が初期化される

### 開発変更の同期

```text
/project-harness:update
```

最終同期コミット以降の変更が反映計画（更新 / 新規 / 整理候補）として提示され、承認した対象がドキュメントへ反映されます。

同期を忘れて開発が進んだ場合は、SessionStart フックがセッション開始時に乖離を検知して update 実行を推奨します（閾値は対象プロジェクトの `.sync-state.json` の `threshold_commits` で調整可能）。

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「プロジェクトの Claude 環境を整備して」「.claude ハーネスを初期化して」 | `harness-init` |
| 「ハーネスを更新して」「変更をドキュメントに反映して」 | `harness-update` |

## ファイル構成

```text
plugins/project-harness/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── commands/
│   ├── init.md                    # /project-harness:init
│   └── update.md                  # /project-harness:update
├── hooks/
│   └── hooks.json                 # SessionStart 鮮度検知フック
├── references/
│   ├── CLAUDE.md                  # プラグイン内 references 索引
│   ├── structure-spec.md          # ハーネス構成仕様（SSOT）
│   ├── sync-spec.md               # 同期仕様（SSOT）
│   ├── scripts/
│   │   └── hooks/
│   │       └── freshness_check.sh # 鮮度検知スクリプト
│   └── template/                  # 対象プロジェクトへ配るドキュメント雛形 11 種
└── skills/
    ├── harness-init/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/            # procedures.md / agents.md
    │   └── evals/                 # 動作分岐の期待挙動 8 ケース
    └── harness-update/
        ├── SKILL.md
        ├── README.md
        ├── references/            # procedures.md / agents.md
        └── evals/                 # 動作分岐の期待挙動 9 ケース
```

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| ハーネスのフォルダ構成・frontmatter 規則 | `references/structure-spec.md`（SSOT） |
| 同期の仕組み（state スキーマ・検出フロー・フック挙動） | `references/sync-spec.md`（SSOT） |
| 生成ドキュメントの雛形 | `references/template/` 配下 |
| 鮮度通知の閾値（プロジェクトごと） | 対象プロジェクトの `.claude/references/.sync-state.json` の `threshold_commits` |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
