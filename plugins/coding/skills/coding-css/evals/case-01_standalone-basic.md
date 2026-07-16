# Case 01: 単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このカードコンポーネントをレスポンシブにして」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | Sass プロジェクト（`package.json` の依存に `sass` / `stylelint`、`.stylelintrc.json` あり）。対象は `_card.scss` の 1 partial。変更見込み 1 ファイル |

## 期待動作

単独実行モードの軽量フロー（規約解決 → FW 確認 → 実装 → 検証 → 報告）を実施する。

### 手順 1: 規約解決
- 規約優先順位の SSOT（`conventions-resolution.md`）に従い、プロジェクト独自規約（`.stylelintrc*` / `.prettierrc*` / `.editorconfig` / `tailwind.config.*` / `CLAUDE.md` / 既存慣習）を走査する
- BEM 採用の有無は既存クラス名の形式（`.card__title` 等）で判定する
- 独自規約がない項目は `references/conventions.md` のデファクト規約で補完する（スペース 2、kebab-case、単一クラス中心で詳細度を低く、モバイルファースト）
- 先頭ゼロ・引用符は Google guide と Prettier 既定が競合するため、ツール設定の有無で判断する
- 規約の矛盾があれば `AskUserQuestion` で確認する（対話モード）。本ケースは方針が自明なため確認なしで進む

### 手順 2: FW 確認
- 依存に `sass` があるため、フロントエンドツールの SSOT（`frontend-tooling.md`）を併用する（`tailwindcss` / `bootstrap` / `vite` があればそれも参照）

### 手順 3: 実装
- 既存の BEM 命名を維持し、モバイルファーストで `@media (min-width: ...)` を積み増す
- `rem` / `%` / `fr` の相対単位を活用する
- 既存ファイルの編集のため、周辺コードのスタイル・エンコーディング・改行コードを維持する

### 手順 4: 検証
- 規約解決で確定したツールチェーンで検証する（`npx stylelint "**/*.{css,scss}"`、`npx prettier --check`）
- 実行不能な検証は SKIPPED として報告する

### 手順 5: 報告
- 変更ファイル・適用規約の根拠（`.stylelintrc` / `.prettierrc` の該当設定 or デファクト）・検証結果を報告する
- 変更見込みが 4 ファイル未満のため `orchestrator-coding` への切替提案は行わない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `_card.scss` |
| 標準出力（要約） | レスポンシブ化の変更点・適用規約の根拠・`stylelint` / `prettier` の結果 |
| 終了状態 | 成功（単独実行モードで完結） |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模が小さく（変更 1 ファイル）言語が CSS / SCSS で明確 である。
このため `orchestrator-coding` の 6 フェーズ統括ではなく、言語スキル単独の軽量フローで処理する。
境界: フェーズ統括・複数言語の併用（マークアップ変更を伴う場合の `coding-html` 等）・設計判断が必要なら `orchestrator-coding` に委ねる。

## 関連ケース

- `case-02_scope-escalation.md`（スコープが 4 ファイル以上に膨らむ場合との対比）
