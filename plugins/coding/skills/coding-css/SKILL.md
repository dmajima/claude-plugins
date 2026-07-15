---
name: coding-css
description: CSS/SCSS のスタイル実装・設計を Google HTML/CSS Style Guide + BEM とプロジェクト規約優先で支援する言語スキル。「CSS を書いて」「レイアウトを直して」「レスポンシブにして」等で起動する。Use when implementing or structuring CSS styles. SKIP when 4+ files or full phases (use orchestrator-coding), design-only (use orchestrator-design), or markup changes (use coding-*).
---

# Coding CSS（CSS 言語スキル）

CSS / SCSS / Sass のデファクト規約（Google HTML/CSS Style Guide / BEM 命名）・スタイル設計・フロントエンドツール知識（Tailwind / Sass / Bootstrap / Vite）を提供する言語スキル。
オーケストレーターからの参照と、単独起動時の軽量実装フローの両方に対応する。

## 責務

- CSS / SCSS / Sass の規約・イディオム・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- フロントエンド FW・ツール固有規約の提供（SSOT `../../references/frameworks/frontend-tooling.md`）
- 単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）
- 設計モードでのスタイル構造ガイダンス（詳細度設計・命名設計・レイアウト方式・レスポンシブ方針）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| マークアップ構造の変更 | `coding-html` |
| Tailwind ユーティリティ運用・ビルドツール詳細 | SSOT `../../references/frameworks/frontend-tooling.md` |
| 他言語のコード | 対応する言語スキル（`../../references/skill-index.md`） |

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が CSS である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なる場合は該当する言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と FW プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「CSS で〜を書いて」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## トリガー条件（単独実行モード）

- 「CSS を書いて」「レイアウトを直して」
- 「レスポンシブ対応して」「SCSS を整理して」

このスキルを起動しないケース:

- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- マークアップ構造の変更（→ `coding-html`）
- CSS / SCSS / Sass 以外の言語（→ 該当する言語スキル）

## 実行フロー（単独実行モード）

1. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`.stylelintrc*`・`.prettierrc*`・`.editorconfig`・`tailwind.config.*`・`CLAUDE.md`・既存慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) のデファクト規約を適用する
2. **FW 確認**: 依存定義・設定に `tailwindcss` / `sass` / `bootstrap` / `vite` 等があれば SSOT `../../references/frameworks/frontend-tooling.md` を併用する。BEM 採用の有無は既存クラス名の形式で判定する
3. **実装**: 解決した規約とスタイル構造ガイダンスに従って実装する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
4. **検証**: 利用可能なツールチェーン（`npx stylelint` / `npx prettier --check` 等、規約解決で確定したもの）で検証する。実行不能な検証は SKIPPED として報告する
5. **報告**: 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（デファクトによる上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）
- 先頭ゼロ・引用符など Google guide と Prettier 既定が競合する項目は、[references/conventions.md](references/conventions.md) に従いツール設定の有無で判断する
- コミット・push はユーザの明示指示があるまで実行しない
- 規約・FW 知識を本文へ直書きせず、references を単一情報源として維持する

## 参照

| 用途 | ファイル |
|-----|---------|
| CSS / SCSS / Sass 言語規約（Google guide / BEM / ツールチェーン / 典型エラー） | [references/conventions.md](references/conventions.md) |
| Tailwind / Sass / Bootstrap / Vite（SSOT・言語横断） | `../../references/frameworks/frontend-tooling.md` |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
