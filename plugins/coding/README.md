# coding

対象リポジトリの言語・フレームワークを自動検出し、プロジェクト規約に準拠した実装・設計を統括する多言語対応プラグイン。ワークフロー統括（orchestrator）と言語知識（言語スキル 8 種）を分離し、設計観点・規約解決などの言語横断ルールを SSOT で一元管理する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `orchestrator-coding` | スキル | 実装ワークフロー統括（6 フェーズ: 指示受領→分析→設計→実装→自己レビュー→報告） |
| `orchestrator-design` | スキル | 設計ワークフロー統括（4 フェーズ: 指示受領→分析→設計→報告、実装なし） |
| `coding-csharp` / `coding-python` / `coding-javascript` / `coding-typescript` / `coding-html` / `coding-css` / `coding-php` / `coding-sql` | 言語スキル × 8 | 言語ごとの規約・コード構造・FW 知識。オーケストレーターからの参照と単独起動の両対応 |
| `/coding` | コマンド | `orchestrator-coding` への薄いラッパー |
| `/design` | コマンド | `orchestrator-design` への薄いラッパー |
| `code-implementer` | エージェント | 設計と規約に従った実コード実装（Edit / Write / Bash 権限あり） |
| `impl-reviewer` | エージェント | 実装品質・規約準拠のレビュー（読み取り専用） |
| `test-engineer` | エージェント | テスト十分性・回帰リスク評価とテスト実行 |
| `architect` | エージェント | 大規模・高リスク変更の設計レビュー（読み取り専用） |

## 対応言語・フレームワーク

| 言語 | 言語スキル（デファクト規約） | 主なフレームワーク |
|------|--------------------------|------------------|
| C# | `coding-csharp`（Microsoft C# Coding Conventions） | ASP.NET Core / EF Core / Blazor / WebForms（レガシー） |
| Python | `coding-python`（PEP 8 / PEP 257） | Flask / Django / FastAPI |
| JavaScript | `coding-javascript`（Prettier デフォルト + 慣習） | Express / NestJS / React / Vue |
| TypeScript | `coding-typescript`（TS 公式 + typescript-eslint） | React / Next.js / Vue / Nuxt / Prisma |
| HTML | `coding-html`（Google HTML/CSS Style Guide） | JSX / SFC / Blade テンプレートの素の HTML 部分 |
| CSS | `coding-css`（Google HTML/CSS Style Guide + BEM） | Tailwind / Sass / Bootstrap |
| PHP | `coding-php`（PSR-1 / PSR-12 / PER） | Laravel / Symfony / WordPress |
| SQL | `coding-sql`（広く受け入れられた慣習 + 方言別公式仕様） | MySQL / SQL Server / PostgreSQL、ORM（Prisma / EF Core / SQLAlchemy / Eloquent） |

ツールチェーン系: Vite / Vitest / Playwright / Jest にも対応。検出マーカーの詳細は `references/skill-index.md` を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- 依存プラグインなし

> **同名プラグインとの競合について（重要）**: 別のマーケットプレイスに同名の `coding` プラグインが存在する環境では、両方をインストールするとスキル・エージェント・コマンドの名前空間 `coding:*` が衝突し、片方の定義が見えなくなります（例: 同名のスキル・エージェントは一方しか解決されません）。**同名プラグインとはどちらか一方のみをインストールしてください**。本プラグインは本 README 記載のモダン多言語スタックを対象とします。

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install coding@dmajima-claude-plugins
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
/plugin install coding@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "source": "github",
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

### 動作確認

```text
/coding
```

タスク内容の確認プロンプトが表示されれば導入完了です。

## 使い方

### スラッシュコマンド

```text
/coding <タスク説明> [--non-interactive]     # 実装ワークフロー（6 フェーズ）
/design <設計対象の説明> [--non-interactive]  # 設計ワークフロー（4 フェーズ、実装なし）
```

`--non-interactive` を付けると、確認プロンプト（AskUserQuestion）を発火せず、最も保守的な解釈を自動採用して進行します（採用した判断は成果物に記録されます）。

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「この機能を実装して」 | `orchestrator-coding`（標準モード・全 6 フェーズ） |
| 「このバグを直して」（小規模） | `orchestrator-coding`（クイックモード） |
| 「この機能の設計をして。実装はまだ」 | `orchestrator-design` |
| 「Python でこの処理を実装して」 | `coding-python`（単独実行モード） |

### 実装ワークフローの流れ

1. **Intake**: タスク分解・不明点確認（implementation-plan.md）
2. **Analyze**: 言語検出 → 言語スキル選択、規約優先順位の解決、影響範囲調査（impact-analysis.md）
3. **Design**: 設計原則 SSOT + 言語スキルのコード構造知識で設計（implementation-design.md）
4. **Implement**: 規約準拠の実装 + ビルド / Lint / テスト検証（file-list.md）
5. **Self-Review**: impl-reviewer + test-engineer の並列レビュー（self-review-result.md）
6. **Report**: 報告書生成 + 機密情報チェック（implementation-report.md）

成果物はセッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/` に生成され、完了時にそのパスが提示されます。

## 規約の優先順位

プロジェクト独自規約が常にデファクト規約より優先されます:

1. ユーザの明示指示
2. プロジェクトの機械設定（`.editorconfig` / リンター・フォーマッタ設定）
3. プロジェクトの文書規約（`CLAUDE.md` / `docs/` の規約文書）
4. 既存コードの一貫した慣習
5. 言語スキルのデファクト規約プロファイル

## アーキテクチャ（SSOT と言語スキルの分離）

| 知識 | 置き場所 |
|------|---------|
| 設計観点・リスクヘッジ・データフロー | SSOT `references/design-principles.md` |
| 規約の優先順位解決・言語検出・成果物テンプレート | SSOT `references/` |
| 言語ごとの規約・コード構造・ツールチェーン | 各言語スキル `skills/coding-{lang}/references/` |
| 言語横断 FW（React / Vue / Node / ORM 等） | SSOT `references/frameworks/` |
| 単一言語専用 FW（.NET / Python Web / PHP Web） | 該当言語スキル内 |

## ファイル構成

```text
plugins/coding/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── commands/
│   ├── coding.md                     # /coding コマンド
│   └── design.md                     # /design コマンド
├── agents/
│   ├── code-implementer.md           # 実装担当（Edit/Write/Bash）
│   ├── impl-reviewer.md              # 実装品質レビュー（read-only）
│   ├── test-engineer.md              # テスト評価（Bash）
│   └── architect.md                  # 設計レビュー（read-only）
├── skills/
│   ├── orchestrator-coding/          # 実装ワークフロー統括（6 フェーズ）
│   │   ├── SKILL.md / README.md
│   │   ├── references/               # workflow.md / agents.md
│   │   └── evals/
│   ├── orchestrator-design/          # 設計ワークフロー統括（4 フェーズ）
│   │   ├── SKILL.md / README.md
│   │   ├── references/               # workflow.md / agents.md
│   │   └── evals/
│   ├── coding-csharp/                # 言語スキル（references/conventions.md + frameworks/dotnet.md + evals/）
│   ├── coding-python/                # 言語スキル（references/conventions.md + frameworks/python-web.md + evals/）
│   ├── coding-javascript/            # 言語スキル（references/conventions.md + evals/）
│   ├── coding-typescript/            # 言語スキル（references/conventions.md + evals/）
│   ├── coding-html/                  # 言語スキル（references/conventions.md + evals/）
│   ├── coding-css/                   # 言語スキル（references/conventions.md + evals/）
│   ├── coding-php/                   # 言語スキル（references/conventions.md + frameworks/php-web.md + evals/）
│   └── coding-sql/                   # 言語スキル（references/conventions.md + 方言 3 種 + evals/）
└── references/                       # プラグイン SSOT（言語横断）
    ├── README.md / CLAUDE.md
    ├── design-principles.md          # 設計観点・リスクヘッジ・データフロー
    ├── conventions-resolution.md     # 規約優先順位の解決
    ├── language-detection.md         # 言語・FW 検出手順
    ├── skill-index.md                # 検出マーカー → 言語スキル対応表
    ├── language-skill-template.md    # 言語スキル追加ガイド
    ├── frameworks/                   # 言語横断 FW（node / react / vue / frontend-tooling / orm）
    └── template/                     # 成果物テンプレート 7 種
```

## カスタマイズ・拡張

| やりたいこと | 方法 |
|-------------|------|
| 新しい言語への対応 | `references/language-skill-template.md` に従い言語スキルを追加 + `references/skill-index.md` に検出マーカー登録 |
| フレームワークの追加 | 単一言語専用は言語スキル内 `references/frameworks/`、言語横断は SSOT `references/frameworks/` に追加 |
| フェーズ手順の調整 | 各オーケストレーターの `references/workflow.md` を編集 |
| 設計観点・リスク分類の変更 | `references/design-principles.md` を編集 |
| 規約優先順位の変更 | `references/conventions-resolution.md` を編集 |
| レビュー観点の調整 | `agents/impl-reviewer.md` / `agents/test-engineer.md` を編集 |

## ライセンス

[MIT License](LICENSE) の下で配布されています。
