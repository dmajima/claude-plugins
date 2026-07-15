# Case 01: 単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この React コンポーネントに props を追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | React + TypeScript プロジェクト（`tsconfig.json` + `package.json`、dependencies に `react`）。対象は既存の `.tsx` コンポーネント 1 ファイル。変更見込み 1〜2 ファイル |

## 期待動作

単独実行モードの実行フロー 5 段を実施する。

### ステップ1: 規約解決
- SSOT `../../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`tsconfig.json` の `strict` / `paths`・`eslint.config.js` / `.eslintrc*`・`.prettierrc*` / `.editorconfig` / 既存慣習）を走査
- 独自規約がない項目は [references/conventions.md](../references/conventions.md) のデファクト規約（TypeScript 公式慣習 + typescript-eslint recommended、JavaScript 規約継承）を適用

### ステップ2: FW 確認
- `package.json` の dependencies に `react` を検出し SSOT `../../../references/frameworks/react.md` を併用（props 型定義・コンポーネント記法慣習）
- `@prisma/client` 等があれば SSOT `../../../references/frameworks/orm.md` を併用

### ステップ3: 実装
- 解決した規約と FW プロファイルに従い、props インターフェースへ新規プロパティを追加し利用箇所へ反映
- `strict` 前提の型安全（`any` の回避・`as any` / `@ts-ignore` での型エラー握り潰し禁止）
- 既存ファイルの編集のため、周辺コードのスタイル・エンコーディング・改行コードを維持

### ステップ4: 検証
- 利用可能なツールチェーン（`package.json` scripts を優先し、`npx tsc --noEmit`（型チェック）/ `npm run lint`（`eslint` + `typescript-eslint`）/ `npm test` のうち規約解決で確定したもの）で検証
- 実行不能な検証は SKIPPED として報告

### ステップ5: 報告
- 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告
- コミット・push はユーザの明示指示があるまで実行しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 規約の矛盾・実装方針の拮抗がなければ AskUserQuestion 不発火 |
| 生成ファイル | リポジトリへのコード変更（`.tsx` 1〜2 ファイル）。セッション成果物 6 種は生成しない |
| 標準出力（要約） | 変更ファイル・適用規約の根拠・検証結果 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模 = 小 かつ 言語 = TypeScript で明確（`tsconfig.json` あり）である。
タスク規模が小さく言語が明確なため、`orchestrator-coding` ではなく言語スキル単独で処理する。
境界: フェーズ統括（6 フェーズの実装ワークフロー）・複数言語・設計判断が必要になる場合は `orchestrator-coding` を使う。`tsconfig.json` の無い JavaScript のみのプロジェクトは `coding-javascript` を使う。

## 関連ケース

- [case-02_scope-escalation.md](case-02_scope-escalation.md)（変更見込みが単独処理の想定規模を超えた場合の切替提案との対比）
