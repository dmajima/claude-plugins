# Case 01: 単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「Express のルートにバリデーションを追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | Express プロジェクト（`package.json` の依存に `express`、`tsconfig.json` なし、`eslint.config.js` + `.prettierrc` あり、`"type": "module"`）。対象は `routes/users.js`。変更見込み 1〜2 ファイル |

## 期待動作

単独実行モードの軽量フロー（規約解決 → FW 確認 → 実装 → 検証 → 報告）を実施する。

### 手順 1: 規約解決
- 規約優先順位の SSOT（`conventions-resolution.md`）に従い、プロジェクト独自規約（`eslint.config.js` / `.eslintrc*` / `.prettierrc*` / `.editorconfig` / `package.json` の `type` / 既存慣習）を走査する
- `.prettierrc` / `eslint.config.js` が存在するため、クォート・セミコロン等はそれが最終的な正となる
- 独自規約がない項目は `references/conventions.md` のデファクト規約で補完する（Prettier 既定: スペース 2、ダブルクォート、末尾セミコロンあり、末尾カンマ all）
- 規約の矛盾があれば `AskUserQuestion` で確認する（対話モード）。本ケースは方針が自明なため確認なしで進む

### 手順 2: FW 確認
- `package.json` の依存に `express` があるため、Node.js サーバー FW の SSOT（`node.md`）を併用する

### 手順 3: 実装
- ESM（`import` / `export`）で記述し、`const` 優先・厳密等価 `===`・`async` / `await`・`Error` の throw・未処理 Promise の回避を守る
- 既存ファイルの編集のため、周辺コードのスタイル・エンコーディング・改行コードを維持する

### 手順 4: 検証
- `package.json` の scripts を優先し、規約解決で確定したツールチェーンで検証する（`npm run lint` / `npx eslint` / `npx prettier --check` / `npm test`（vitest））
- 実行不能な検証は SKIPPED として報告する

### 手順 5: 報告
- 変更ファイル・適用規約の根拠（`.prettierrc` / `eslint.config.js` の該当設定 or デファクト）・検証結果を報告する
- 変更見込みが 4 ファイル未満のため `orchestrator-coding` への切替提案は行わない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `routes/users.js`（必要に応じてテスト 1 ファイル） |
| 標準出力（要約） | 追加したバリデーション・適用規約の根拠・`eslint` / `prettier` / `test` の結果 |
| 終了状態 | 成功（単独実行モードで完結） |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模が小さく（変更 1〜2 ファイル）言語が JavaScript で明確（`tsconfig.json` なし）である。
このため `orchestrator-coding` の 6 フェーズ統括ではなく、言語スキル単独の軽量フローで処理する。
境界: フェーズ統括・複数言語の併用・設計判断が必要なら `orchestrator-coding` に委ねる。`tsconfig.json` があれば `coding-typescript` に切り替える。

## 関連ケース

- `case-02_scope-escalation.md`（スコープが 4 ファイル以上に膨らむ場合との対比）
