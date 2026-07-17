# HTML レビュー観点プロファイル

HTML およびテンプレート内の素のマークアップの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.html` / `.htm`（素の HTML）。テンプレート内の素マークアップ部分も対象 |
| マーカーファイル | 単一のマーカーは持たない（拡張子の出現数で検出）。整形設定として `.editorconfig` / `.prettierrc*`、検証設定として `.htmlvalidate.json` が併存しうる |
| 対象外 | `.vue` / `.jsx` / `.tsx` / `.blade.php` / `.twig` / `.erb` 等のテンプレート構文自体は各フレームワークプロファイルで扱う（セクション5）。本プロファイルは静的 HTML とテンプレート内の素マークアップに適用する |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- Google HTML/CSS Style Guide（大文字小文字の統一・id/class 区切り・セマンティクス・関心の分離）
- WHATWG HTML Living Standard（要素のセマンティクス・妥当な入れ子・ブール属性）
- WCAG 2.2 / WAI-ARIA Authoring Practices Guide（アクセシビリティ）

## 3. レビュー観点

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

### 3.4 セキュリティ【担当: web-designer / security-engineer】

- [ ] インラインイベントハンドラ（`onclick` / `onload` 等）へ動的値を埋め込んでいないか（XSS。イベントは外部 JS の `addEventListener` へ分離）
- [ ] `target="_blank"` のリンクに `rel="noopener"`（必要に応じて `noreferrer`）があるか（reverse tabnabbing）
- [ ] 外部 CDN の `<script>` / `<link>` に SRI（`integrity` + `crossorigin`）が付いているか
- [ ] `http://` リソースの読み込みがないか（mixed content。明示的に `https://` を使う）
- [ ] `<iframe>` に `sandbox` / `referrerpolicy` 等の制限があるか、`srcdoc` に未エスケープ値を渡していないか
- [ ] `href="javascript:..."` や `data:` URI へ信頼できない値を埋め込んでいないか
- [ ] フォームの `action` が意図した同一オリジン / 信頼先か・機微情報を `method="get"`（URL 露出）で送信していないか
- [ ] CSP（`<meta http-equiv="Content-Security-Policy">` またはヘッダ）と矛盾するインラインスクリプト / スタイルへの依存が増えていないか

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

### 3.7 テンプレートエンジン（Liquid / DotLiquid / Razor / Blade / Jinja2 等）【担当: web-designer / security-engineer】

> 本観点は FW プロファイル（`../frameworks/php-web.md` の Blade / Twig、`dotnet.md` の Razor 等）と **意図的に重複カバー** する（XSS はクリティカル経路のため、FW プロファイル未適用時にも本ファイルが安全網として機能する設計）。セクション 1 の「対象外」宣言はマークアップ構造の主管を示すもので、エスケープ安全性の観点は本セクションが横断的に扱う。

- [ ] エスケープ迂回に信頼できない値を渡していないか: Liquid / DotLiquid の生出力、Razor `Html.Raw()` / `@Html.Raw`、Blade `{!! !!}`、Jinja2 `| safe`、ERB `raw` / `<%== %>`（XSS）
- [ ] 既定の自動エスケープ（`{{ }}` / `@` 記法）を無効化していないか、生出力の対象が本当に安全と保証できる値に限定されているか
- [ ] 属性値 / `href` / `src` / インラインイベント / `<script>` 内へのテンプレート変数展開に**文脈別**エスケープが効いているか（HTML エスケープだけでは JS / URL 文脈は防げない）
- [ ] テンプレート内ロジックの肥大化（多重ネストの条件分岐・DB アクセスや重い計算の直接呼び出し）。表示ロジックへ委譲されているか
- [ ] 部分テンプレート / インクルードへ未検証のユーザー入力をパス指定していないか（テンプレートインジェクション・パストラバーサル）
- [ ] ループ内での重い処理・N+1 誘発（コレクション反復中の遅延ロード）がないか

### 3.8 コメント・メタ情報整合【担当: web-designer】

- [ ] `<meta charset="utf-8">` が `<head>` の先頭付近にあるか・非 UTF-8 保存による文字化けがないか
- [ ] `<title>` / `meta[name=description]` / OGP 等のメタ情報が内容と整合しているか（差分でコンテンツだけ変わり古いまま等）
- [ ] `<link rel="canonical">` / `hreflang` の指定先に重複・不整合がないか
- [ ] コメント（`<!-- -->`）の記述と実マークアップの乖離・コメントアウトされた旧マークアップの残留がないか
- [ ] デバッグ用コメント・作業メモの本番残留がないか

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| インラインハンドラ / テンプレート生出力への未エスケープ値埋め込み | Critical | XSS |
| エスケープ迂回（`Html.Raw` / `{!! !!}` / `\| safe` / 生出力）へ信頼できない値 | Critical | XSS |
| `http://` リソース混在（mixed content） | High | 通信改ざん・ブラウザブロック |
| `img` の `alt` 欠落・フォーム `label` 未関連付け | High | アクセシビリティ阻害（操作・読み上げ不能） |
| `<div onclick>` 等でのクリック要素代替 | High〜Medium | キーボード操作・支援技術対応の喪失 |
| `target="_blank"` の `rel="noopener"` 欠落 | High〜Medium | reverse tabnabbing |
| 外部 CDN スクリプトの SRI 欠落 | High〜Medium | サプライチェーン改ざん |
| ARIA 誤用・不要 ARIA | Medium〜High | 支援技術での誤読・操作不能 |
| `id` 重複・不正な入れ子 | Medium | 参照破壊・レンダリング不定 |
| `img` の width/height 欠落（CLS）・lazy 未指定 | Medium | 体感性能の劣化 |
| 非推奨要素・命名 / スタイル規約違反 | Medium〜Low | 保守性・規約整合 |
| ブール属性の冗長記述・実体参照の多用 | Low | 任意改善（既存スタイルとの整合を優先） |

### NG / OK 例（XSS: インラインハンドラ・テンプレート生出力）

```html
<!-- NG: ユーザー入力をインラインハンドラと生出力へ直接展開（XSS） -->
<button onclick="showUser('{{ user_name }}')">表示</button>
<div>{{ comment_html | safe }}</div>

<!-- OK: 挙動は外部 JS の addEventListener で data 属性経由、値は既定の自動エスケープに委ねる -->
<button type="button" class="show-user" data-user="{{ user_name }}">表示</button>
<div>{{ comment_text }}</div>
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| React / Next.js コンポーネント内マークアップ（JSX / TSX） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| Vue / Nuxt コンポーネント内マークアップ（SFC `.vue`） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| スタイル（CSS / インライン `style` / クラス設計）の評価 | `${CLAUDE_PLUGIN_ROOT}/references/languages/css.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| マークアップ検証 | `npx html-validate "**/*.html"` | error = 強制 FAIL（High〜Medium）、warning = Medium〜Low |
| 軽量 Lint | `npx htmlhint "**/*.html"` | error 件数に応じて Medium〜Low |
| 整形 | `npx prettier --check "**/*.html"` | 差分あり = Low〜Medium |
| アクセシビリティ監査（任意） | Lighthouse / axe-core（ブラウザ・CI 実行） | 違反の深刻度に応じて付与 |
