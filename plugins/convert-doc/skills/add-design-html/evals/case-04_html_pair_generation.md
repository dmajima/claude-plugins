# Case 04: HTML ペア生成（構造変更デザイン）

## 入力

- ユーザー依頼: 「上部に固定ヘッダーバーがあるデザインを追加して。ヘッダーには文書タイトルを表示」
- CSS だけでは表現できない構造要素（ヘッダーバー）が必要

## 期待動作

1. CSS のみでは実現不可と判断し、HTML ペア生成をユーザーに提案・確認する
2. `template.html` をベースに `<design-name>.html` を生成する
   - プレースホルダ 6 種をすべて維持
   - 骨格 DOM（`#wrap` / `#main-content` / `.doc-title` / `.article-body`）を維持
   - ヘッダーバー等の追加要素に `toc-` / `lb-` プレフィクスの ID を使わない
3. `validate_css.py` と `validate_html.py` の**両方**で PASS を確認する
4. サンプル変換で `--css-template` と `--html-template` の両方を指定する
5. 配置時は CSS と HTML を同名ペアで配置する

## 期待出力

- `<design-name>.css` + `<design-name>.html` のペア（両方 PASS 済み）
- JS 機能（目次トグル・ライトボックス）が動作する構造

## 分岐の根拠

`SKILL.md`「HTML 構造変更の原則」:
> CSS だけで表現できないデザインに限り、同名 HTML テンプレートをペア生成する
> ペア HTML は JS 契約に影響しない変更のみ許可

## 関連ケース

- [case-01_interactive_css_only.md](case-01_interactive_css_only.md): CSS のみで足りる場合
