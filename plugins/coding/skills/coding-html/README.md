# coding-html スキル

HTML（`.html` / `.htm`、およびフレームワークテンプレート内の素の HTML 部分）のデファクト規約・文書構造・アクセシビリティ基本知識を提供する言語スキル。`orchestrator-coding` / `orchestrator-design` からの参照と、単独起動時の軽量実装フローの両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作定義は `SKILL.md`、規約の実体は `references/conventions.md` にあります。

## 使い方

### 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | `references/conventions.md` を規約・構造の判定基準として提供する（フェーズ制御は行わない） |
| 単独実行モード | ユーザの直接依頼 | 規約解決 → 実装 → 検証 の軽量フローを実施する |

### 単独起動のトリガーフレーズ例

| 発話例 | 動作 |
|-------|------|
| 「HTML を書いて」 | 規約準拠でマークアップを生成 |
| 「このページのマークアップを直して」 | 既存 HTML を規約・セマンティクスに沿って修正 |
| 「フォームを追加して」 | `label` 関連付け等アクセシビリティ基本を満たすフォームを追加 |

## 対応フレームワーク・ツール

| 種別 | 対象 | 参照先（SSOT） |
|------|------|--------------|
| テンプレート（JSX / TSX） | React / Next.js | `../../references/frameworks/react.md` |
| テンプレート（SFC） | Vue / Nuxt | `../../references/frameworks/vue.md` |
| テンプレート（Blade / Twig） | Laravel / Symfony 等 | `../coding-php/references/frameworks/php-web.md` |
| 検証・整形 | html-validate / Prettier / ブラウザ DevTools | `references/conventions.md` |

素の HTML 部分のみ本スキルが担当し、テンプレートの FW 固有構文は上記プロファイルが担当します。

## カスタマイズ

| やりたいこと | 方法 |
|-------------|------|
| デフォルト規約の調整 | `references/conventions.md` を編集 |
| プロジェクト独自規約の反映 | 対象リポジトリの `.editorconfig` / `.prettierrc*` / `.htmlvalidate.json` / `CLAUDE.md` に定義（独自規約が優先） |
| 新しい言語への対応 | プラグイン SSOT `../../references/language-skill-template.md` に従い言語スキルを追加 |

## ファイル構成

```text
skills/coding-html/
├── SKILL.md                 # 言語スキル定義（動作エントリポイント）
├── README.md                # 本ファイル（人間向け）
└── references/
    └── conventions.md       # HTML 言語規約（デファクト規約の SSOT）
```

規約優先順位の解決・設計原則・FW プロファイル（react / vue）はプラグイン直下 `references/`（SSOT）を参照する。
