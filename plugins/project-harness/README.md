# project-harness

対象プロジェクトに AI エージェントの足場となる `.claude` ハーネス（`CLAUDE.md` + `references/` 配下の仕様・設計・検証環境ドキュメント体系）を初期構築し、開発・修正で生じたコード変更を随時ドキュメントへ同期する環境整備プラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `harness-init` | スキル | プロジェクトを解析（サブエージェント並列調査）して `.claude` ハーネスを初期構築し、`.sync-state.json` を初期化 |
| `harness-update` | スキル | 最終同期コミットと HEAD の差分から影響ドキュメントを特定し、記載・索引・同期状態を最新化（`--full` で全量監査） |
| `/project-harness:init` | コマンド | `harness-init` への薄いラッパー |
| `/project-harness:update` | コマンド | `harness-update` への薄いラッパー |
| 鮮度検知フック | フック（SessionStart） | 最終同期からの乖離コミット数が閾値（既定 10）に達したとき `/project-harness:update` の実行を推奨通知 |
| ハーネス検証スクリプト | スクリプト | 索引一致・frontmatter・行数・プレースホルダ・秘匿値・到達性を機械検証（両スキルの検証フェーズが実行） |

## 構築されるハーネス構成

対象プロジェクトに以下が生成されます（詳細仕様は `references/structure-spec.md`）:

```text
<target-repo>/
├── CLAUDE.md                      # ハーネス入口（@.claude/CLAUDE.md の import。既存があれば追記）
└── .claude/
    ├── CLAUDE.md                  # プロジェクト概要・技術スタック（常時読込・100 行以内）
    └── references/
        ├── CLAUDE.md              # ドキュメント索引・整理ルール
        ├── .sync-state.json       # 同期状態（仕様バージョン・最終同期コミット・閾値）
        ├── specs/                 # 仕様設計書（画面遷移・画面構成・業務ルール・アプリ動作）
        ├── system-designs/        # 詳細設計書（specs 対応・実装で詳細化すべき設計情報）
        ├── flows/                 # 画面位置・アクセス手順
        ├── environments/          # ビルド・テスト・起動・検証コマンド（検証ハーネス）
        ├── conventions/           # コーディング規約・命名・配置・コミット/PR 規約
        ├── architecture/          # システム構成・モジュール依存・データモデル
        ├── decisions/             # ADR（設計判断記録）
        └── glossary.md            # ドメイン用語集
```

各ドキュメントは frontmatter の `sources`（対応ソースパスのグロブ）を持ち、`harness-update` が git 差分と照合して影響ドキュメントだけを更新します。大規模・モノレポではパッケージ単位のサブ名前空間（`specs/<package>/<feature>.md`）を適用できます。

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

# 2. ブランチ・タグを切り替える場合
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

依存プラグインはありません。

**外部ツール依存（利用者環境に必要なもの）**

| ツール | 用途 |
|-------|------|
| git 2.30+ | 同期基準にコミット SHA を使用するため必須 |
| bash | SessionStart フックと検証スクリプトの実行に必要（Windows は Git Bash 同梱のもので可） |
| jq | 任意。あれば `.sync-state.json` の読み取りに使用し、無ければ sed にフォールバック |

### 動作確認

インストール後に Claude Code を再起動し、`/project-harness:` まで入力して `init` / `update` が補完候補に表示されることを確認します。

## 使い方

### 初期構築

対象プロジェクト（git リポジトリ）で実行します:

```text
/project-harness:init
```

別のリポジトリを対象にする場合はパスを渡します（**独立した git リポジトリのルート** を指定してください。既存リポジトリのサブフォルダは対象外です）:

```text
/project-harness:init ../another-repo
```

大規模プロジェクトでは並列調査とドキュメント生成に数分かかる場合があります。

1. 既存資産（ルート CLAUDE.md・README・docs/）の取り込み方針を確認
2. サブエージェントがプロジェクトを並列調査（技術スタック / 機能・画面 / アーキテクチャ / 規約・用語）
3. 生成範囲（全機能 / 主要機能のみ / 個別選択）を選択
4. `environments/` に記載する検証コマンドの実行可否を確認（対象リポジトリのコード実行を伴うため）
5. ハーネス一式が生成され、検証スクリプトが実行され、`.sync-state.json` が初期化される

### 開発変更の同期

```text
/project-harness:update
```

最終同期コミット以降の変更が反映計画（更新 / ソース移動 / 新規 / 整理候補）として提示され、承認した対象がドキュメントへ反映されます。

用語集・規約など対応ソースを持たないドキュメントも含めて棚卸しする場合は全量監査モードを使います:

```text
/project-harness:update --full
```

同期を忘れて開発が進んだ場合は、SessionStart フックがセッション開始時に乖離を検知して update 実行を推奨します（閾値は対象プロジェクトの `.sync-state.json` の `threshold_commits` で調整可能。通知を止めたい場合は十分大きい値を設定します）。

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「プロジェクトの Claude 環境を整備して」「仕様・設計ドキュメント体系を作って」 | `harness-init` |
| 「ハーネスを更新して」「変更をドキュメントに反映して」 | `harness-update` |

### 他機能との関係

| 対象 | 関係 |
|------|------|
| Claude Code 組み込みの `/init` | 別機能です。組み込み `/init` はリポジトリルートの `CLAUDE.md` を生成します。`/project-harness:init` は `.claude/` 配下のドキュメント体系を構築し、ルート `CLAUDE.md` には `@.claude/CLAUDE.md` の import 行を追記して入口をつなぎます（既存記述は削除しません） |
| `/maintenance:update`（maintenance プラグイン） | 無関係です。あちらはプラグイン自体の更新、`/project-harness:update` は対象プロジェクトのドキュメント同期です |
| `coding` プラグイン | `coding` の規約検出は現状 `.claude/references/conventions/` を走査しません。主要な規約は `.claude/CLAUDE.md` の要約にも残すことで、ルート `CLAUDE.md` の import 経由で参照されるようにしてください |

## ファイル構成

```text
plugins/project-harness/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── commands/
│   ├── init.md                     # /project-harness:init
│   └── update.md                   # /project-harness:update
├── hooks/
│   └── hooks.json                  # SessionStart 鮮度検知フック
├── references/
│   ├── README.md                   # references/ の人間向けインデックス
│   ├── CLAUDE.md                   # エージェント向け原則・ナビゲーション
│   ├── structure-spec.md           # ハーネス構成仕様（SSOT）
│   ├── authoring-spec.md           # 作成・検証の共通規則（SSOT）
│   ├── sync-spec.md                # 同期仕様（SSOT）
│   ├── scripts/
│   │   ├── CLAUDE.md
│   │   ├── hooks/
│   │   │   └── freshness_check.sh  # 鮮度検知スクリプト
│   │   └── validate/
│   │       └── validate_harness.sh # ハーネス健全性の検証スクリプト
│   └── templates/                  # 対象プロジェクトへ配るドキュメント雛形 11 種
│       └── CLAUDE.md
└── skills/
    ├── harness-init/
    │   ├── SKILL.md
    │   ├── README.md
    │   ├── references/             # procedures.md / agents.md
    │   └── evals/                  # 動作分岐の期待挙動 13 ケース
    └── harness-update/
        ├── SKILL.md
        ├── README.md
        ├── references/             # procedures.md / agents.md
        └── evals/                  # 動作分岐の期待挙動 15 ケース
```

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| ハーネスのフォルダ構成・frontmatter と sources 記法・モノレポ適用 | `references/structure-spec.md`（SSOT。追加時の更新対象は節 9.1） |
| 記載の原則・秘匿情報の扱い・検証項目 | `references/authoring-spec.md`（SSOT） |
| 同期の仕組み（state スキーマ・検出フロー・フック挙動） | `references/sync-spec.md`（SSOT） |
| 生成ドキュメントの雛形 | `references/templates/` 配下 |
| 鮮度通知の閾値（プロジェクトごと） | 対象プロジェクトの `.claude/references/.sync-state.json` の `threshold_commits` |
| フックの動作診断 | 環境変数 `PROJECT_HARNESS_DEBUG` を設定して起動すると、判定経路が stderr に出力されます |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
