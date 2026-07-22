# Case 03: 非対話モードでの単独実行

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「このユーティリティ関数に型定義を追加して --non-interactive」 |
| 引数 | タスク説明 |
| フラグ | `--non-interactive` |
| 既存状態 | TypeScript プロジェクト（`tsconfig.json` あり）。型の厳密度（具体的 union か汎用ジェネリックか）が未指定。ユーザの直接依頼で `coding-typescript` を単独起動（orchestrator を経由しない） |

## 期待動作

単独実行モードの実行フロー 5 段を、実行モード判定表の非対話行（`--non-interactive` → 確認をスキップし、最も保守的な解釈を採用して進行する。採用した判断は報告に記録する）に従って実施する。

### 全ステップ共通
- `AskUserQuestion` を発火させず、不明点（型の厳密度）は最も保守的な解釈を採用して進行する
- 採用したデフォルト判断を報告に必ず記録する

### ステップ1〜2: 規約解決・FW 確認
- 独自規約（`tsconfig.json` の `strict` / `paths`・`eslint.config.js` / `.eslintrc*`・`.prettierrc*`・`.editorconfig`）を走査する
- 規約に矛盾があっても確認せず、SSOT `../../../references/conventions-resolution.md` の優先順位で機械的に解決し、採用理由を記録する
- 該当する FW 依存が無ければ言語規約のみで進める

### ステップ3: 実装
- 型は最も型安全な保守的判断を採用する（`any` を避け、`tsconfig.json` の `strict` 前提で具体的な型を付与する）
- `as any` / `@ts-ignore` での型エラー握り潰し禁止など [references/conventions.md](../references/conventions.md) の必須事項を維持する

### ステップ4〜5: 検証・報告
- 利用可能なツールチェーン（`npx tsc --noEmit` / `npm run lint` 等）で検証する。実行不能な検証は SKIPPED として報告する
- 採用したデフォルト判断・適用規約の根拠・検証結果を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 0 回（AskUserQuestion 不発火） |
| 生成ファイル | リポジトリへのコード変更。報告にデフォルト判断（型の厳密度）の記録あり |
| 終了状態 | 成功（保守的解釈で完了） |

## 分岐の根拠

このケースが分岐するトリガーは フラグ = `--non-interactive` である。
実行モード判定表の非対話行「確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録）」を単独実行フロー全体に適用する。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（対話モードで規約の矛盾・方針の拮抗時に AskUserQuestion を発火する基本フローとの対比）
- [case-04_convention-conflict.md](case-04_convention-conflict.md)（対話モードで検出規約とユーザ指示が矛盾し AskUserQuestion が発火するケースとの対比）
