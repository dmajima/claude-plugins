# case-10 認可・入力検証削除の回帰検出（U16: 認可チェック / 入力検証削除）

リファクタリングの差分の削除側（`-` 行）で、既存の認可チェック（`[Authorize]` / 権限判定）や入力検証が失われた回帰を security-engineer が指摘するケース。新規コードの脆弱性ではなく、既存の防御がリファクタで削られた回帰（U16）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ（リファクタリング）> <プロジェクト規約サマリ> mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 変更分類 | リファクタリング（コントローラ整理・共通化） |
| 差分内容 | アクションメソッドのリファクタリングに伴い、削除側（`-` 行）で `[Authorize(Roles = "Admin")]` 属性・明示的な権限判定（`if (!user.HasPermission(...)) return Forbid();`）・リクエストパラメータの入力検証（`ModelState.IsValid` / 範囲・型ガード）が除去され、追加側（`+` 行）では同等の認可・検証が再導入されていない |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` U16（差分の削除側で既存の防御コード（例外処理・入力検証・リソース解放・a11y 属性・認可・エラー表示 UI）が失われていれば回帰として指摘する）、`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` U16「対象とする防御コード」（認可・認証チェック（`[Authorize]` / 権限確認 / CSRF トークン検証）・入力検証・境界チェック・ガード節）・「判定」（削除行の防御が追加行で再導入されていなければ回帰・意図と区別できない場合は信頼度中程度で意図確認）、references/checklist.md セクション A U16。ドメイン固有の回帰パターンとして、認可属性・権限判定の削除は OWASP A01（Broken Access Control）の後退、入力検証の削除は OWASP A03（Injection）等の攻撃面の再導入として security-engineer 観点（SKILL.md「前提」の観点表: 認証/認可・入力検証）で評価する。silent-failure（新規コードの握りつぶし）ではなく、リファクタで既存防御が削られるケースを扱う点で他観点と別物。

## 期待動作

- security-engineer が差分の削除側（`-` 行）を精査し、認可チェック（`[Authorize]` / ロール判定 / 権限確認 / CSRF トークン検証）・入力検証・境界チェックが失われていないか確認する（universal-rules.md U16 / checklist.md セクション A U16）
- 削除された防御コードが追加側（`+` 行）で同等に再導入されていない場合、回帰（regression）として指摘する（universal-rules.md U16「判定」）
- 具体的には、認可属性・権限判定の消失を「アクセス制御の後退（Broken Access Control の回帰）」、入力検証の消失を「入力検証欠落によるインジェクション面の再導入の回帰」として指摘する（universal-rules.md U16「対象とする防御コード」・SKILL.md「出力フォーマット」の OWASP/STRIDE 分類）
- language-profiles で受領した言語・FW プロファイルの OWASP 観点（A01 / A03 等）を根拠に引用する（O10）
- 新規コードの silent-failure 観点とは切り分け、あくまで「リファクタで既存の防御が削られた」回帰として位置づける（universal-rules.md U16 規範）
- 意図的削除（別レイヤーで認可が担保される等の正当理由）と区別できない場合は、信頼度を中程度にし「回帰の可能性・意図確認」として提示する（universal-rules.md U16「判定」/ U15 信頼度付与）
- 各指摘に重要度・信頼度・スコープ内/外フラグを付与する（checklist.md U11 / U15 / O5）
- 中間レポートは「## セキュリティ観点レビュー結果」+「### security-engineer」「### dependency-safety」の構造で返却する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1）
- Finding ID（CR-NNN）の採番・Verdict 判定は行わない（checklist.md O9。オーケストレーター責務）

## 関連ケース

- case-04: セキュリティレビューフレーズでの起動（security-engineer の通常脅威モデリング観点）
- case-09: 重要度付与・重複統合（U11）+ 信頼度付与・足切り境界（U15）
