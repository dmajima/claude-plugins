---
name: coding-html
description: HTML のマークアップ実装・構造設計を Google HTML/CSS Style Guide とプロジェクト規約優先で支援する言語スキル。「HTML を書いて」「フォームを追加して」「マークアップを直して」等で起動する。Use when implementing or structuring HTML markup. SKIP when 4+ files or full phases (use orchestrator-coding), design-only (use orchestrator-design), or style/logic changes (use coding-*).
---

# Coding HTML（HTML 言語スキル）

HTML のデファクト規約（Google HTML/CSS Style Guide / セマンティック HTML / アクセシビリティ基本）・文書構造・テンプレート内の素の HTML 知識を提供する言語スキル。
オーケストレーターからの参照と、単独起動時の軽量実装フローの両方に対応する。

## 責務

- HTML の規約・イディオム・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- セマンティック HTML・アクセシビリティ基本（`img` の `alt` / `label` 関連付け / 見出し階層）のガイダンス
- 単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）
- 設計モードでの文書構造ガイダンス（ページ領域の要素構成・見出し階層・フォーム構造）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| CSS / スタイルの実装 | `coding-css` |
| コンポーネントロジック（JSX / SFC のスクリプト部） | `coding-javascript` / `coding-typescript` |
| テンプレート形式（JSX / Vue SFC / Blade）の FW 固有構文 | SSOT `../../references/frameworks/react.md` / `../../references/frameworks/vue.md`、`../coding-php/references/frameworks/php-web.md` |
| 他言語のコード | 対応する言語スキル（`../../references/skill-index.md`） |

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が HTML である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なる場合は該当する言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と FW プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「HTML で〜を書いて」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## トリガー条件（単独実行モード）

- 「HTML を書いて」「このページのマークアップを直して」
- 「フォームを追加して」「テーブルのマークアップを直して」

このスキルを起動しないケース:

- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- スタイルの変更（→ `coding-css`）
- コンポーネントロジック・スクリプト（→ `coding-javascript` / `coding-typescript`）

## 実行フロー（単独実行モード）

1. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`.editorconfig`・`.prettierrc*`・`.htmlvalidate.json`・`CLAUDE.md`・既存慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) のデファクト規約を適用する
2. **FW 確認**: 対象がテンプレート（`.jsx` / `.tsx` / `.vue` / `.blade.php` 等）の場合は素の HTML 部分のみを担当し、FW 固有構文は SSOT `../../references/frameworks/react.md` / `../../references/frameworks/vue.md` / `../coding-php/references/frameworks/php-web.md` を参照する
3. **実装**: 解決した規約と文書構造ガイダンスに従って実装する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
4. **検証**: 利用可能な範囲でブラウザ表示確認・`npx html-validate`（利用可能な場合）・アクセシビリティ基本チェック（`img` の `alt` / `label` 関連付け / 見出し階層）を行う。実行不能な検証は SKIPPED として報告する
5. **報告**: 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（デファクトによる上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）
- `<!DOCTYPE html>`・`lang` 属性・`<meta charset="utf-8">`・`img` の `alt` など、[references/conventions.md](references/conventions.md) の必須事項を省略しない
- コミット・push はユーザの明示指示があるまで実行しない
- 規約・FW 知識を本文へ直書きせず、references を単一情報源として維持する

## 参照

| 用途 | ファイル |
|-----|---------|
| HTML 言語規約（Google HTML/CSS Style Guide / セマンティクス / アクセシビリティ / 典型エラー） | [references/conventions.md](references/conventions.md) |
| React / Next.js（JSX / TSX テンプレート）（SSOT） | `../../references/frameworks/react.md` |
| Vue / Nuxt（SFC テンプレート）（SSOT） | `../../references/frameworks/vue.md` |
| Laravel / Symfony 等（Blade / Twig テンプレート） | `../coding-php/references/frameworks/php-web.md` |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
