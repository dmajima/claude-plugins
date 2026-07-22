# Case 04: 対話モードで検出規約とユーザ指示が矛盾 → AskUserQuestion 発火

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この処理を手早く書きたいので引数の型は any でいい」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | TypeScript プロジェクト。`tsconfig.json` に `"strict": true`、`eslint.config.js` に `@typescript-eslint/no-explicit-any` が有効。ユーザの明示指示（`any` 許容）が機械設定と矛盾する |

## 期待動作

### ステップ1: 規約解決（矛盾の検出）
- SSOT `../../../references/conventions-resolution.md` に従い機械設定（`tsconfig.json`: `strict`、`eslint`: `no-explicit-any`）を検出する
- ユーザの明示指示（`any` 許容）は優先度 1、機械設定は優先度 2。両者が型の厳密度で矛盾することを把握する

### 矛盾時の確認（対話モード）
- 実行モード判定表の対話行「規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する」に従い発火する
- `AskUserQuestion` で提示する: (a) ユーザ指示（`any` 許容）を優先（優先順位 1・推奨。ただし `no-explicit-any` の Lint エラー発生を明示）/ (b) 機械設定に合わせ具体的な型を付与する
- 回答された方針を確定し、採用理由（優先順位・矛盾があった旨・Lint への影響）を報告に記録する

### ステップ3以降: 実装・検証・報告
- 確定した規約で実装する。`as any` / `@ts-ignore` での型エラー握り潰し禁止など [references/conventions.md](../references/conventions.md) の必須事項は（機械設定に合わせる場合）維持する
- 利用可能なツールチェーン（`npx tsc --noEmit` / `npm run lint` 等）で検証し（実行不能は SKIPPED）、矛盾の解決結果を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 1 回以上（規約の矛盾を AskUserQuestion で確認） |
| 生成ファイル | 確定方針でのコード変更。報告に矛盾の解決記録あり |
| 終了状態 | 成功（ユーザ確認後に実装） |

## 分岐の根拠

このケースが分岐するトリガーは 対話モード かつ 検出規約（`tsconfig.json` / `eslint`）とユーザ指示の矛盾 である。
実行モード判定表の対話行「規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する」を、SSOT `../../../references/conventions-resolution.md` の優先順位（ユーザ指示 = 1 > 機械設定 = 2）と併せて適用する。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（矛盾がなく AskUserQuestion 不発火の基本フローとの対比）
- [case-03_non-interactive.md](case-03_non-interactive.md)（非対話モードでは矛盾を確認せず優先順位で機械的に解決する点が対照的）
