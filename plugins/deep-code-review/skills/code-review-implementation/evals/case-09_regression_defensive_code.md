# case-09 防御コード削除の回帰検出（U16）

リファクタリングの差分の削除側（`-` 行）で、既存の例外処理・リソース解放が失われた回帰を implementation-engineer が指摘するケース。新規コードの silent-failure（握りつぶし）ではなく、既存の防御がリファクタで削られた回帰（U16）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ（リファクタリング）> <プロジェクト規約サマリ> mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 変更分類 | リファクタリング |
| 差分内容 | データアクセス処理のリファクタリング。旧コードの `try { ... } catch (SqlException ex) { _logger.LogError(ex); throw; } finally { conn.Dispose(); }` が削除され、新コードでは `try/catch`・`finally`・`using` のいずれも再導入されていない（例外ハンドリングとリソース解放の両方が削除側に存在し、追加側に同等物が無い） |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` U16（差分の削除側で既存の防御コード（例外処理・入力検証・リソース解放・a11y 属性・認可・エラー表示 UI）が失われていれば回帰として指摘する）、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16「対象とする防御コード」（例外処理 / リソース解放（`using` / `finally`））・「判定」（削除行の防御が追加行で再導入されていなければ回帰・意図と区別できない場合は信頼度中程度で意図確認）、references/checklist.md セクション A の U16 行。

**既存ケースとの差別化**: U16 は「リファクタで既存の防御が削られる」ケースを扱い、新規コードの握りつぶしを扱う silent-failure 観点（言語プロファイル 3.2）とは別物（universal-rules.md U16 規範に明記）。case-01 / case-04 は防御コード消失を主題化しない通常の実装品質フローであり、本ケースは削除側（`-` 行）の防御消失検出という U16 固有の分岐を検証する。

## 期待動作

- implementation-engineer が差分の削除側（`-` 行）を精査し、既存の例外処理（`try/catch`）・リソース解放（`using` / `finally` / `Dispose`）が失われていないか確認する（universal-rules.md U16 / checklist.md セクション A U16）
- 削除された防御コードが追加側（`+` 行）で同等に再導入されていない場合、回帰（regression）として指摘する（universal-rules.md U16「判定」）
- 具体的には、`finally` / `using` によるリソース解放の消失を「リソースリークの回帰」、`catch` による例外ハンドリングの消失を「未捕捉例外の伝播（例外握り漏れ）の回帰」として指摘する（universal-rules.md U16「対象とする防御コード」）
- 新規コードの silent-failure（握りつぶし）観点とは切り分け、あくまで「リファクタで既存の防御が削られた」回帰として位置づける（universal-rules.md U16 規範）
- 意図的削除（防御が不要になった正当理由）と区別できない場合は、信頼度を中程度にし「回帰の可能性・意図確認」として提示する（universal-rules.md U16「判定」/ U15 信頼度付与）
- 指摘には致命度・指摘箇所・該当コード・求める修正・理由・根拠・信頼度を漏れなく含める（SKILL.md「実行フロー」手順 4 / checklist.md U15）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9。オーケストレーター責務）

## 関連ケース

- case-01: 委譲・spec_summary なし（防御コード消失を主題化しない通常の実装品質フロー）
- case-04: 実装正確性を含む総合トリガー（implementation-engineer の通常観点）
