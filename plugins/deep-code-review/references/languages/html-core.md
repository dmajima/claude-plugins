# HTML レビュー観点プロファイル — core details

`html.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `html.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.5 3.6 3.8 を収録。

### 3.1 セマンティクス・文書構造【担当: web-designer】

- [ ] `<div>` / `<span>` の濫用（`header` / `nav` / `main` / `article` / `section` / `aside` / `footer` で表現できる領域を汎用要素で組んでいないか）
- [ ] 見出しレベルの飛ばし（`h1` の次に `h3` 等）・装飾目的での見出しレベル選択がないか
- [ ] `main` はページ 1 個・`h1` は原則 1 個か
- [ ] クリック可能要素を `<div onclick>` / `<span onclick>` で代替していないか（遷移は `a[href]`、操作・送信は `button`）
- [ ] `href` の無い空 `<a>` や、リンクテキストが「こちら」「詳細」等で文脈非依存になっていないか
- [ ] 妥当な入れ子か（`<p>` 内へのブロック要素配置、`<ul>` / `<ol>` 直下の `<li>` 以外、`<table>` の `thead` / `tbody` 欠落 等）
- [ ] 非推奨の要素・属性（`<center>` / `<font>` / `align` / `bgcolor` 等）を使用していないか
- [ ] `<!DOCTYPE html>` が文書先頭にあるか（HTML5 を使用し XHTML でないか）

### 3.2 アクセシビリティ（WCAG）【担当: web-designer】

- [ ] `<img>` に `alt` があるか（意味を持つ画像は内容を説明、装飾画像は `alt=""`）（WCAG 1.1.1）
- [ ] フォーム入力が `<label for="id">` または `label` 内包で関連付けられているか（WCAG 1.3.1 / 4.1.2）
- [ ] ARIA の乱用がないか（ネイティブ要素・属性で表現できる場合は ARIA を付けない。**不要な `role` / 冗長な `aria-*` はむしろ有害**）（First Rule of ARIA）
- [ ] `role` / `aria-*` の値・対応関係が正しいか（`aria-labelledby` の参照先 id が実在するか、`role="button"` への `tabindex` とキーボードハンドラの欠落がないか）
- [ ] すべての操作がキーボードで実行可能か・カスタム操作要素のフォーカス管理（`tabindex` / フォーカストラップ / フォーカスの可視化）が適切か（WCAG 2.1.1）
- [ ] データ表のヘッダ関連付け（`<th scope>` / `<caption>`）があるか、レイアウト目的の `<table>` を使っていないか
- [ ] 情報伝達を色・形状のみに依存していないか（状態をテキスト / アイコンでも示すか。詳細な配色・コントラストは `languages/css.md` 参照）（WCAG 1.4.1）
- [ ] 本文へのスキップリンク等、ランドマークによるナビゲーション補助が用意されているか
- [ ] `<html lang="...">` で主要言語が指定されているか（WCAG 3.1.1）

### 3.3 フォーム・入力【担当: web-designer】

- [ ] `input` の `type` が用途に合っているか（メール→`email`、電話→`tel`、数値→`number`、URL→`url`。何でも `type="text"` にしていないか）
- [ ] 必須・書式の制約が HTML 側にあるか（`required` / `pattern` / `min` / `max` / `maxlength`）。クライアント JS のみに依存していないか
- [ ] `autocomplete` 属性が適切か（氏名・住所・ワンタイムコード等は標準トークンを指定、機微情報での `off` 要否）
- [ ] 送信ボタンが `<button type="submit">`、非送信ボタンが `type="button"` になっているか（`<button>` の既定 `type` は `submit`）
- [ ] 関連するラジオ / チェックボックス群を `<fieldset>` + `<legend>` でグルーピングしているか
- [ ] 各入力に送信キーとなる `name` 属性があるか（`name` 欠落でサーバへ送信されない見落とし）
- [ ] 入力とラベル・エラーメッセージの関連付け（`aria-describedby` / `aria-invalid`）があるか

### 3.5 命名・スタイル【担当: web-designer / linter-static-analysis】

- [ ] 要素名・属性名・属性値が小文字か（`<SECTION>` / `maxLength` 不可）
- [ ] `id` / `class` が目的を表す kebab-case か（CSS 命名規約と整合。詳細は `languages/css.md` 参照）
- [ ] `id` がページ内で一意か（重複はラベル参照・スクリプトを壊す）
- [ ] インデント（スペース 2）・属性値のダブルクォート・末尾空白の除去（`.editorconfig` / Prettier があればそちらに従う）
- [ ] 構造・表現・振る舞いの分離（インライン `style` 属性の乱用がないか。表示は CSS へ委ねているか）
- [ ] ブール属性は属性名のみで記述しているか（`required="required"` 等の冗長記述・過剰な実体参照を避ける）

### 3.6 パフォーマンス【担当: web-designer / performance-reviewer】

- [ ] `<img>` / `<iframe>` にファーストビュー外の `loading="lazy"` が検討されているか
- [ ] `<img>` に `width` / `height`（または `aspect-ratio`）指定があるか（CLS 防止）
- [ ] レスポンシブ画像（`srcset` / `sizes` / `<picture>`）が必要な箇所で使われているか
- [ ] `<meta name="viewport" content="width=device-width, initial-scale=1">` があるか
- [ ] レンダリングブロッキング（`<head>` 内の同期 `<script>`）を避け `defer` / `async` / 末尾配置になっているか
- [ ] 重要リソースの `preload` / `preconnect`、フォント読み込み戦略（`font-display`）が検討されているか

### 3.8 コメント・メタ情報整合【担当: web-designer】

- [ ] `<meta charset="utf-8">` が `<head>` の先頭付近にあるか・非 UTF-8 保存による文字化けがないか
- [ ] `<title>` / `meta[name=description]` / OGP 等のメタ情報が内容と整合しているか（差分でコンテンツだけ変わり古いまま等）
- [ ] `<link rel="canonical">` / `hreflang` の指定先に重複・不整合がないか
- [ ] コメント（`<!-- -->`）の記述と実マークアップの乖離・コメントアウトされた旧マークアップの残留がないか
- [ ] デバッグ用コメント・作業メモの本番残留がないか

