# Case 05: 言語境界のルーティング（tsconfig.json 無し → coding-javascript）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このコンポーネントを書いて」（TypeScript のつもりで `coding-typescript` を直接起動） |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | プロジェクトに `tsconfig.json` が無く、対象ファイルは `.js`／`.jsx`。実体は JavaScript のみのプロジェクト |

## 期待動作

### 前提チェックでの境界検出
- 前提「対象コードの言語が TypeScript である」を確認する過程で `tsconfig.json` が無く `.js`／`.jsx` のみであることを検出する
- 責務外表「JavaScript のみのコード（`tsconfig.json` 無し） → `coding-javascript`」に該当することを把握する

### ルーティング
- 起動しないケース「`tsconfig.json` の無い JavaScript のみのプロジェクト（→ `coding-javascript`）」に従い、`coding-typescript` の単独実行フローには進まない
- 対象は JavaScript であり `coding-javascript` の使用が適切である旨をユーザに案内する（型前提の TS 規約を持ち込まない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ルーティング | `coding-javascript` を案内（TS として実装しない） |
| 生成ファイル | `coding-typescript` としてのコード変更なし（言語境界判定で委譲） |
| 終了状態 | 成功（適切なスキルへ案内） |

## 分岐の根拠

このケースが分岐するトリガーは 言語境界 = JavaScript（`tsconfig.json` 無し）である。
`coding-typescript` の責務外表・起動しないケースに定義された TS / JS 境界（`tsconfig.json` の有無）を検証する。境界判定の材料は SSOT `../../../references/skill-index.md` の検出マーカーに基づく。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（`tsconfig.json` があり TypeScript として単独処理する基本フローとの対比）
- `../../coding-javascript/evals/case-05_language-boundary.md`（JS → TS の逆方向境界）
