# coding-php スキル

PHP のデファクト規約（PSR-1 / PSR-12 / PER Coding Style）・コード構造・主要フレームワーク（Laravel / Symfony / WordPress）の知識を提供する言語スキル。`orchestrator-coding` / `orchestrator-design` からの参照と、単独起動時の軽量実装フローの両方に対応する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキルの動作定義は `SKILL.md` と `references/` を参照してください。

## 導入手順

本スキルは `coding` プラグインに同梱されています。プラグイン本体の導入手順（マーケットプレイス登録・インストール・自動更新）は [プラグイン README](../../README.md) を参照してください。本スキル単体での追加インストールは不要です。

導入後は `orchestrator-coding` / `orchestrator-design` から自動的に参照されるほか、下記「使い方」のトリガーフレーズでユーザが直接起動できます。

## 使い方

このスキルには 2 つの利用モードがある。

### 1. オーケストレーターからの参照（参照モード）

`orchestrator-coding`（実装ワークフロー）や `orchestrator-design`（設計ワークフロー）が PHP プロジェクトを検出した際に、本スキルの `references/` を規約・構造の判定基準として参照する。ユーザが直接起動する必要はない。

### 2. 単独起動（単独実行モード）

小規模な PHP の実装・修正では、以下のようなフレーズで直接起動する。

| 発話例 | 動作 |
|-------|------|
| 「PHP で〜を実装して」 | 規約解決 → 実装 → 検証の軽量フロー |
| 「この PHP コードを直して」 | 既存スタイルを維持して修正 |
| 「Laravel のコントローラを書いて」 | php-web.md の FW 規約を併用して実装 |

変更が 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する。

## 対応フレームワーク

| フレームワーク | 検出マーカー | 規約系統 |
|--------------|-------------|---------|
| Laravel | `composer.json` の `laravel/framework` / `artisan` | PSR 準拠（PSR-1 / PSR-12 / PER） |
| Symfony | `composer.json` の `symfony/*` / `bin/console` | PSR 準拠 |
| WordPress | `wp-config.php` / `wp-content/` | **WordPress Coding Standards（PSR と異なる独自規約）** |

FW 固有規約は `references/frameworks/php-web.md`、言語横断の ORM 知識（Eloquent を含む）は SSOT `../../references/frameworks/orm.md` に集約している。WordPress は PSR と大きく異なるため、同一コードベースで複数 FW の規約を混在させないこと。

## カスタマイズ

| やりたいこと | 編集対象 |
|-------------|---------|
| PHP のデファクト規約・命名・ツールチェーンを調整 | `references/conventions.md`（本スキルの SSOT） |
| フレームワーク固有規約を追加・修正 | `references/frameworks/php-web.md` |
| 規約の優先順位ルールを変更 | プラグイン共通 `../../references/conventions-resolution.md` |

## ファイル構成

```text
skills/coding-php/
├── SKILL.md                        # スキル定義（本スキルのエントリポイント）
├── README.md                       # 本ファイル（人間向け）
└── references/
    ├── conventions.md              # PHP 言語規約の SSOT
    └── frameworks/
        └── php-web.md              # Laravel / Symfony / WordPress
```
