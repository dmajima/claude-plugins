# case-09 WCAG 個別達成基準の網羅評価（アクセシビリティ）

web-designer が WCAG の個別達成基準（コントラスト比 / キーボード操作 / ARIA / 代替テキスト）を網羅的に評価する分岐を検証する。トリガー起動を確認する case-04 に対し、本ケースは評価観点の深さ（どの WCAG 基準を適用するか）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/html.md(主), languages/css.md mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | UI 変更（`.html` / `.css`）。`alt` 欠落の `<img>`・`<div onclick>`・低コントラストの配色・`<label>` 未関連付けのフォームを含む |

## 分岐の根拠

`${CLAUDE_PLUGIN_ROOT}/references/languages/html.md` 観点 3.2（アクセシビリティ WCAG: alt / label 関連付け / ARIA 乱用 / キーボード操作 / lang）、`${CLAUDE_PLUGIN_ROOT}/references/languages/css.md` 観点 3.4（コントラスト比 WCAG AA 4.5:1・フォーカス可視性・色のみの状態伝達）、html.md セクション 4 / css.md セクション 4 の重要度目安、web-designer 担当。トリガー起動を検証する case-04 との差は、個別達成基準の網羅評価という深さにある。

## 期待動作

- 代替テキストを評価する: `<img>` の `alt` 欠落を検出し、意味を持つ画像は内容説明・装飾画像は `alt=""` を求める（WCAG 1.1.1 / html.md 3.2 = High）
- キーボード操作を評価する: `<div onclick>` / `<span onclick>` によるクリック要素代替を検出し、遷移は `a[href]`・操作は `button` へ、フォーカス管理（`tabindex` / フォーカス可視化）を求める（WCAG 2.1.1 / html.md 3.2）
- ARIA を評価する: 不要な `role` / 冗長な `aria-*`（First Rule of ARIA 違反）・`aria-labelledby` の参照先 id 不在・`role="button"` へのキーボードハンドラ欠落を検出する（html.md 3.2）
- コントラスト比を評価する: テキストと背景のコントラスト比不足（WCAG AA 通常 4.5:1 / 大 3:1）を検出する（css.md 3.4 = High）
- 代替の状態伝達を評価する: 色のみで状態（エラー / 成功 / 必須）を伝えていないか（WCAG 1.4.1 / css.md 3.4）、フォーカスリング除去（`outline: none` 単独）が無いか（css.md 3.4 = High）を確認する
- フォームのラベル関連付け（`<label for>` / `aria-describedby`）・`<html lang>` 指定を確認する（WCAG 1.3.1 / 3.1.1 / html.md 3.2）
- 各指摘に重要度（html.md / css.md セクション 4 の目安に沿う）・信頼度・スコープ内/外フラグを付与する（U11 / U15 / O5）

## 関連ケース

- case-04: アクセシビリティ確認フレーズでの起動（トリガー検証・本ケースは評価の深さ）
- case-07: 防御コード削除（a11y 属性）の回帰検出
- case-08: Liquid / DotLiquid テンプレートの評価
