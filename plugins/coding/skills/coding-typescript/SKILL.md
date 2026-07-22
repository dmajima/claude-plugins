---
name: coding-typescript
description: TypeScript の実装・設計を TS 公式+typescript-eslint とプロジェクト規約優先で支援する言語スキル。「TS で書いて」「型エラーを直して」「コンポーネントを書いて」等で起動する。Use when implementing or structuring TypeScript code. SKIP if 4+ files/full phases (orchestrator-coding), design-only (orchestrator-design), or JS/other languages (coding-*).
---

# Coding TypeScript（TypeScript 言語スキル）

TypeScript のデファクト規約（TypeScript 公式慣習 + typescript-eslint recommended、JavaScript 規約を継承）・コード構造・フレームワーク知識（Express / NestJS / React / Vue / フロントエンドツール / Prisma）を提供する言語スキル。
オーケストレーター参照と単独起動時の軽量実装フローに対応する。

## 責務

- TypeScript の規約・イディオム・型安全のベストプラクティス・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- 単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）
- 設計モードでのコード構造ガイダンス（モジュール構成・ディレクトリ配置・レイヤ分割・型設計）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| Node.js サーバー FW（Express / NestJS） | SSOT `../../references/frameworks/node.md` |
| React / Next.js | SSOT `../../references/frameworks/react.md` |
| Vue / Nuxt | SSOT `../../references/frameworks/vue.md` |
| フロントエンドツール（Vite / Tailwind / Vitest / Jest / Playwright） | SSOT `../../references/frameworks/frontend-tooling.md` |
| ORM（Prisma 等）の横断知識 | SSOT `../../references/frameworks/orm.md` |
| JavaScript のみのコード（`tsconfig.json` 無し） | `coding-javascript` |
| 他言語のコード | 対応する言語スキル（`../../references/skill-index.md`） |

## トリガー条件（単独実行モード）

- 「TypeScript で実装して」「この TS の型エラーを直して」
- 「React コンポーネントを書いて」「NestJS のサービスを追加して」

起動しないケース:

- `tsconfig.json` の無い JavaScript のみのプロジェクト（→ `coding-javascript`）
- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- TypeScript 以外の言語（→ 該当する言語スキル）

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が TypeScript である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なれば該当言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と SSOT FW プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「TypeScript で〜を実装して」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## 実行フロー（単独実行モード）

1. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`tsconfig.json` の `strict` / `paths`・`eslint.config.js` / `.eslintrc*`・`.prettierrc*`・`.editorconfig`・既存慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) のデファクト規約を適用する
2. **FW 確認**: `package.json` の dependencies に応じて該当する SSOT FW プロファイルを併用する（`express` / `@nestjs/core` → `../../references/frameworks/node.md`、`react` / `next` → `../../references/frameworks/react.md`、`vue` / `nuxt` → `../../references/frameworks/vue.md`、`vite` / `vitest` / `jest` / `@playwright/test` 等 → `../../references/frameworks/frontend-tooling.md`）。`prisma/schema.prisma` / `@prisma/client` があれば ORM 横断知識 `../../references/frameworks/orm.md` を併用する
3. **実装**: 解決した規約とコード構造ガイダンスに従って実装する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
4. **検証**: 利用可能なツールチェーン（プロジェクトの `package.json` scripts を優先し、`npx tsc --noEmit`（型チェック） / `npm run lint`（`eslint` + `typescript-eslint`） / `npm test` 等、規約解決で確定したもの）で検証する。実行不能な検証は SKIPPED として報告する
5. **報告**: 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（デファクトによる上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）。`tsconfig.json` の `strict` / `paths` 等はプロジェクト設定が最終的な正である
- `strict` 前提の型安全（`any` の回避・`as any` / `@ts-ignore` での型エラー握り潰し禁止）など、[references/conventions.md](references/conventions.md) の必須事項を省略しない
- コミット・push はユーザの明示指示があるまで実行しない

## 参照

| 用途 | ファイル |
|-----|---------|
| TypeScript 言語規約（型安全 / 命名 / ツールチェーン / 典型エラー） | [references/conventions.md](references/conventions.md) |
| Express / NestJS（SSOT） | `../../references/frameworks/node.md` |
| React / Next.js（SSOT） | `../../references/frameworks/react.md` |
| Vue / Nuxt（SSOT） | `../../references/frameworks/vue.md` |
| フロントエンドツール（SSOT） | `../../references/frameworks/frontend-tooling.md` |
| ORM 横断知識（Prisma 等・SSOT） | `../../references/frameworks/orm.md` |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
