# case-08 Liquid / DotLiquid テンプレートの評価（テンプレートエンジン観点）

差分に Liquid / DotLiquid テンプレート（`.liquid`）が含まれるケース。web-designer が html.md のテンプレートエンジン観点（エスケープ迂回・文脈別エスケープ・テンプレートインジェクション）で評価する分岐を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/html.md(主), languages/css.md mode=standard`（`.liquid` テンプレートの変更を含む） |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | Liquid / DotLiquid テンプレート（`.liquid`）+ 付随する CSS。ユーザー入力を出力する箇所・部分テンプレート include を含む |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/languages/html.md` 観点 3.7（テンプレートエンジン: Liquid / DotLiquid の生出力・エスケープ迂回・文脈別エスケープ・部分テンプレートへの未検証入力・ループ内の重い処理）およびセクション 4 の典型指摘（テンプレート生出力への未エスケープ値 = Critical）、web-designer エージェント定義（HTML / CSS に加え Liquid / DotLiquid テンプレートの品質を評価）、SKILL.md「前提」の観点表（テンプレートエンジン: Razor / Liquid / Blade / Twig / Jinja2 等）。

## 期待動作

- web-designer は html.md 観点 3.7 を Liquid / DotLiquid に適用し、生出力（Liquid raw / DotLiquid の生出力）へ信頼できない値を渡すエスケープ迂回を XSS として検出する（html.md 3.7 / セクション 4 = Critical）
- 既定の自動エスケープ（`{{ }}`）を無効化していないか、生出力の対象が安全と保証できる値に限定されているかを確認する（html.md 3.7）
- 属性値 / `href` / `src` / インラインイベント / `<script>` 内へのテンプレート変数展開に**文脈別**エスケープが効いているかを確認する（HTML エスケープだけでは JS / URL 文脈は防げない）（html.md 3.7）
- 部分テンプレート / include へ未検証のユーザー入力をパス指定していないか（テンプレートインジェクション・パストラバーサル）、ループ内での N+1 誘発がないかを確認する（html.md 3.7）
- テンプレート内の素マークアップのセマンティクス・a11y も html.md 3.1〜3.2 で併せて評価する
- XSS（Critical）等の重大指摘は深いセキュリティ評価が必要な場合 `code-review-security` へ誘導する（O4。html.md 3.7 は FW プロファイル未適用時の安全網として横断カバー）
- 各指摘に重要度・信頼度・スコープ内/外フラグを付与する（U11 / U15 / O5）

## 関連ケース

- case-05: language-profiles 受領（React + JSX・別テンプレート方式の対比）
- case-04: アクセシビリティ確認フレーズでの起動
- case-09: WCAG 個別達成基準の網羅評価
