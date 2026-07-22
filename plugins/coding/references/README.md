# references/ ディレクトリ（人間向けインデックス）

coding プラグインのプラグイン共通リソース（SSOT）の人間向けインデックス。本ファイルはエージェント動作では使用されない（エージェント向けの原則・ナビゲーションは [`CLAUDE.md`](CLAUDE.md) が正典。各サブディレクトリの詳細は [`frameworks/CLAUDE.md`](frameworks/CLAUDE.md) / [`template/CLAUDE.md`](template/CLAUDE.md) を参照）。

## 構成

| パス | 内容 |
|------|------|
| [design-principles.md](design-principles.md) | 設計観点・リスクヘッジ・データフローの言語横断ルール（SSOT） |
| [conventions-resolution.md](conventions-resolution.md) | コーディング規約の優先順位解決（プロジェクト独自規約 > デファクト） |
| [language-detection.md](language-detection.md) | 言語・フレームワーク検出手順 |
| [skill-index.md](skill-index.md) | 検出マーカーと言語スキルの対応表（SSOT） |
| [frameworks/](frameworks/) | 言語横断フレームワークプロファイル（React / Vue / Node / frontend-tooling / ORM） |
| [template/](template/) | ワークフロー成果物テンプレート 7 種 |
| [language-skill-template.md](language-skill-template.md) | 言語スキル追加ガイド |

## SSOT と言語スキルの分担

| 知識 | 置き場所 |
|------|---------|
| 設計観点・リスク・データフロー / 規約解決 / 検出手順 / テンプレート | 本ディレクトリ（SSOT） |
| 言語固有の規約・コード構造・ツールチェーン | `skills/coding-{lang}/references/` |
| 単一言語専用 FW（.NET / Python Web / PHP Web） | 該当言語スキル内の `references/frameworks/` |
| 言語横断 FW（React / Vue / Node / frontend-tooling / ORM） | 本ディレクトリの `frameworks/` |

## 言語スキル一覧（デファクト規約）

| 言語スキル | 準拠するデファクト規約 |
|-----------|---------------------|
| `coding-csharp` | Microsoft C# Coding Conventions / .NET Naming Guidelines |
| `coding-python` | PEP 8 / PEP 257 |
| `coding-javascript` | Prettier デフォルト + 広く採用される慣習 |
| `coding-typescript` | TypeScript 公式 + typescript-eslint 慣習 |
| `coding-html` / `coding-css` | Google HTML/CSS Style Guide |
| `coding-php` | PSR-1 / PSR-12 / PER Coding Style |
| `coding-sql` | 広く受け入れられた慣習 + 各 DBMS 公式仕様（MySQL / SQL Server / PostgreSQL） |

## 拡張方法

1. [language-skill-template.md](language-skill-template.md) に従い `skills/coding-{lang}/` を作成する
2. [skill-index.md](skill-index.md) に検出マーカーを登録する
3. 複数言語で共有する FW は `frameworks/` に、単一言語専用 FW は言語スキル内に配置する
