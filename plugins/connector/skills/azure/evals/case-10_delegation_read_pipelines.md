# Case 10: 他プラグイン委譲による Pipelines ビルド結果取得（パターン B・読み取り）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:azure", args: "読み取りのみ。https://dev.azure.com/contoso/WebApp のプロジェクト WebApp のビルド 5678 の結果・テスト結果・ログを取得して")` |
| 既存状態 | 呼び出し元は coding プラグイン。`az` CLI ログイン済み。**後続フローなし（取得結果の報告で呼び出し元のターンが完了する文脈）** — 後続フローがある場合は `Skill()` ではなく `Agent()` を使う（delegation-interface.md セクション 3） |

## 期待動作

1. パターン B（読み取りのみ）と判別
2. 認証確認（`az account show`）
3. Pipelines API でビルド結果・テスト結果を取得
4. 結果を **解釈・要約せずそのまま** 呼び出し元に返す（外部由来データ境界マーカー付き）
5. Pipelines ログにシークレットパターンが含まれる場合は警告を付与

## 分岐の根拠

パターン B + 読み取り系。安全ゲート不要。Pipelines API 経路の初の eval。`Skill()` 委譲が正当なのは後続フローなしの場合のみで、後続フローのある read は `case-11_subagent_read_pr.md`（`Agent()` 経由）が対比となる。
