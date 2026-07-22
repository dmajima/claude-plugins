# coding-css スキル

CSS / SCSS / Sass（`.css` / `.scss` / `.sass`）のデファクト規約・スタイル設計・フロントエンドツール知識を提供する言語スキル。`orchestrator-coding` / `orchestrator-design` からの参照と、単独起動時の軽量実装フローの両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作定義は `SKILL.md`、規約の実体は `references/conventions.md` にあります。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は `orchestrator-coding` / `orchestrator-design` から自動的に参照されるほか、下記「使い方」のトリガーフレーズでユーザが直接起動できます。

## 使い方

### 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | `references/conventions.md` を規約・構造の判定基準として提供する（フェーズ制御は行わない） |
| 単独実行モード | ユーザの直接依頼 | 規約解決 → 実装 → 検証 の軽量フローを実施する |

### 単独起動のトリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「CSS を書いて」 | 規約準拠でスタイルを生成 |
| 「Flexbox でレイアウトして」 | Flexbox / Grid で既存レイアウトを調整 |
| 「レスポンシブ対応して」 | モバイルファーストのメディアクエリを追加 |

## 対応フレームワーク・ツール

| 種別 | 対象 | 参照先（SSOT） |
|------|------|--------------|
| ユーティリティ / プリプロセッサ / UI FW / ビルド | Tailwind / Sass / Bootstrap / Vite | `../../references/frameworks/frontend-tooling.md` |
| Lint・整形 | stylelint / Prettier | `references/conventions.md` |
| 検証・デバッグ | W3C CSS Validation Service / ブラウザ DevTools | `references/conventions.md` |

命名は Google HTML/CSS Style Guide 準拠の kebab-case を基本とし、プロジェクトが BEM を採用している場合はそれに従います。

## カスタマイズ

| やりたいこと | 方法 |
|-------------|------|
| デフォルト規約の調整 | `references/conventions.md` を編集 |
| プロジェクト独自規約の反映 | 対象リポジトリの `.stylelintrc*` / `.prettierrc*` / `.editorconfig` / `tailwind.config.*` / `CLAUDE.md` に定義（独自規約が優先） |
| 新しい言語への対応 | プラグイン SSOT `../../references/language-skill-template.md` に従い言語スキルを追加 |

## ファイル構成

```text
skills/coding-css/
├── SKILL.md                 # 言語スキル定義（動作エントリポイント）
├── README.md                # 本ファイル（人間向け）
└── references/
    └── conventions.md       # CSS / SCSS / Sass 言語規約（デファクト規約の SSOT）
```

規約優先順位の解決・設計原則・FW プロファイル（frontend-tooling）はプラグイン直下 `references/`（SSOT）を参照する。
