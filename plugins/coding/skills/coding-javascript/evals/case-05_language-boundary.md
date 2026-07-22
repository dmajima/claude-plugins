# Case 05: 言語境界のルーティング（tsconfig.json 検出 → coding-typescript）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この関数の型を直して」（JavaScript のつもりで `coding-javascript` を直接起動） |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | プロジェクトルートに `tsconfig.json` が存在し、対象ファイルは `.ts`。実体は TypeScript プロジェクト |

## 期待動作

### 前提チェックでの境界検出
- 前提「対象コードの言語が JavaScript である」を確認する過程で `tsconfig.json`（および `.ts` 拡張子）を検出する
- 責務外表「TypeScript のコード（`tsconfig.json` 検出時） → `coding-typescript`」に該当することを把握する

### ルーティング
- 起動しないケース「`tsconfig.json` のある TypeScript プロジェクト（→ `coding-typescript`）」に従い、`coding-javascript` の単独実行フローには進まない
- 対象は TypeScript であり `coding-typescript` の使用が適切である旨をユーザに案内する（誤って JS 規約で実装しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ルーティング | `coding-typescript` を案内（JS として実装しない） |
| 生成ファイル | `coding-javascript` としてのコード変更なし（言語境界判定で委譲） |
| 終了状態 | 成功（適切なスキルへ案内） |

## 分岐の根拠

このケースが分岐するトリガーは 言語境界 = TypeScript（`tsconfig.json` 検出）である。
`coding-javascript` の責務外表・起動しないケースに定義された JS / TS 境界（`tsconfig.json` の有無）を検証する。境界判定の材料は SSOT `../../../references/skill-index.md` の検出マーカーに基づく。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（`tsconfig.json` が無く JavaScript として単独処理する基本フローとの対比）
- `../../coding-typescript/evals/case-05_language-boundary.md`（TS → JS の逆方向境界）
