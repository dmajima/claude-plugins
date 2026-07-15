---
name: coding-php
description: PHP のコード実装・構造設計を PSR-12 / PER とプロジェクト規約優先で支援する言語スキル。「PHP で実装して」「この PHP を直して」「Laravel のコントローラを書いて」等で起動する。Use when implementing or structuring PHP code. SKIP when 4+ files or full phases (use orchestrator-coding), design-only (use orchestrator-design), or other languages (use coding-*).
---

# Coding PHP（PHP 言語スキル）

PHP のデファクト規約（PSR-1 / PSR-12 / PER Coding Style）・コード構造・フレームワーク知識（Laravel / Symfony / WordPress）を提供する言語スキル。
オーケストレーターからの参照と、単独起動時の軽量実装フローの両方に対応する。

## 責務

- PHP の規約・イディオム・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- PHP Web フレームワーク固有規約の提供（[references/frameworks/php-web.md](references/frameworks/php-web.md)）
- 単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）
- 設計モードでのコード構造ガイダンス（ディレクトリ構成・名前空間（PSR-4）配置・レイヤ分割）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| ORM（Eloquent 等）の横断知識 | SSOT `../../references/frameworks/orm.md` |
| 他言語のコード | 対応する言語スキル（`../../references/skill-index.md`） |

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が PHP である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なる場合は該当する言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と FW プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「PHP で〜を実装して」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## トリガー条件（単独実行モード）

- 「PHP で実装して」「この PHP コードを修正して」
- 「Laravel のコントローラを書いて」「PHPUnit のテストを追加して」

このスキルを起動しないケース:

- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- PHP 以外の言語（→ 該当する言語スキル）

## 実行フロー（単独実行モード）

1. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`.php-cs-fixer.php`・`.php-cs-fixer.dist.php`・`phpcs.xml`・`phpstan.neon`・`composer.json`・`CLAUDE.md`・既存慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) のデファクト規約を適用する
2. **FW 確認**: `composer.json` の require に `laravel/framework` / `symfony/*` があれば、または `wp-config.php` が存在すれば [references/frameworks/php-web.md](references/frameworks/php-web.md) を、Eloquent 等の ORM があれば SSOT `../../references/frameworks/orm.md` を併用する
3. **実装**: 解決した規約とコード構造ガイダンスに従って実装する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
4. **検証**: 利用可能なツールチェーン（`composer install` 済みを前提に `phpunit` / `php-cs-fixer fix --dry-run` / `phpstan analyse` 等、規約解決で確定したもの）で検証する。実行不能な検証は SKIPPED として報告する
5. **報告**: 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（デファクトによる上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）
- PSR-4 準拠のファイル名＝クラス名一致・クラス定数の `UPPER_SNAKE_CASE` など、[references/conventions.md](references/conventions.md) の必須事項を省略しない
- WordPress を対象とする場合は PSR ではなく WordPress Coding Standards に従う（同一コードベースで規約を混在させない。詳細: [references/frameworks/php-web.md](references/frameworks/php-web.md)）
- コミット・push はユーザの明示指示があるまで実行しない
- 規約・FW 知識を本文へ直書きせず、references を単一情報源として維持する

## 参照

| 用途 | ファイル |
|-----|---------|
| PHP 言語規約（PSR / ツールチェーン / 典型エラー） | [references/conventions.md](references/conventions.md) |
| Laravel / Symfony / WordPress | [references/frameworks/php-web.md](references/frameworks/php-web.md) |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| ORM 横断知識（SSOT） | `../../references/frameworks/orm.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
