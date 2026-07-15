# CSS 言語プロファイル

> 本プロファイルは「プロジェクト独自規約が存在しない場合のデフォルト」である。プロジェクト設定（`.stylelintrc*` / `.prettierrc*` / `.editorconfig` / `CLAUDE.md` 等）が存在する場合の優先順位は [`conventions-resolution.md`](../../../references/conventions-resolution.md) に従う。

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.css`, `.scss`（SCSS 構文）, `.sass`（インデント構文） |
| マーカーファイル | 単一のマーカーは持たない（拡張子で検出）。lint 設定 `.stylelintrc*`、`package.json` の依存に `sass` / `stylelint` / `postcss` / `autoprefixer` があれば当該ツールチェーンと判断 |

## 2. デファクトスタンダード規約

**準拠規約**: Google HTML/CSS Style Guide（https://google.github.io/styleguide/htmlcssguide.html）

命名手法・Sass 運用は以下を参照する。

- BEM（https://getbem.com/ / https://en.bem.info/methodology/） — 命名手法（Google スタイルとは別体系。セクション 4 参照）
- Sass 公式（https://sass-lang.com/） / Sass Guidelines（https://sass-guidelin.es/） — Sass の運用・命名

### 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| クラス名 | 小文字 + ハイフン区切り（kebab-case）。単語をハイフン以外で連結しない | `.video-title`（`.videoTitle` / `.video_title` 不可） |
| 命名の意味 | 見た目ではなく **目的・役割** を表す。変わりにくい意味的な名前を優先 | `.alert`（`.red-text` 不可）、`.gallery`（`.grid-3col` より汎用的） |
| カスタムプロパティ | kebab-case。用途がわかる名前 | `--color-primary`、`--space-md` |
| Sass 変数 / mixin / function / placeholder | kebab-case（小文字ハイフン区切り） | `$brand-color`、`@mixin card-shadow`、`%visually-hidden` |
| ファイル名 | kebab-case。Sass の部分ファイル（partial）は先頭に `_` | `main.css`、`_buttons.scss` |

出典: kebab-case のハイフン区切りは Google HTML/CSS Style Guide "ID and class name delimiters"、目的に沿った命名は同 "Class naming"。partial の `_` 接頭辞は Sass 公式仕様、Sass 識別子の kebab-case は Sass Guidelines。

### 2.2 インデント・フォーマット

| 項目 | 規定 | 出典 |
|------|------|------|
| インデント | スペース 2 個 | Google guide "Indentation" |
| 宣言末尾 | すべての宣言をセミコロンで終える | Google guide "Declaration stops" |
| コロン後の空白 | プロパティ名の後のコロンに続けて空白 1 個（`color: red;`） | Google guide "Property name stops" |
| セレクタと `{` | 最後のセレクタと `{` の間に空白 1 個、`{` は同一行に置く | Google guide "Declaration block separation" |
| セレクタ・宣言の改行 | セレクタごと・宣言ごとに改行（1 行 1 セレクタ / 1 宣言） | Google guide "Selector and declaration separation" |
| ルール間 | ルール間は空行 1 行で区切る | Google guide "Rule separation" |
| 0 の単位 | `0` 値の後の単位を省略（`margin: 0;`） | Google guide "0 and units" |
| 先頭ゼロ | -1〜1 の値の先頭 `0` を省略（`.8em`）。**Prettier は逆に付与する**ため Prettier 採用時はそれに従う | Google guide "Leading zeros" / Prettier 既定 |
| 16 進カラー | 小文字。可能なら 3 文字表記（`#ebc`） | Google guide "Hexadecimal notation" / "3 character hexadecimal notation" |
| 引用符 | Google guide は CSS では単一引用符 `'...'` を推奨。**Prettier 既定はダブル**のため Prettier 採用時はそれに従う | Google guide "CSS quotation marks" / Prettier 既定 |
| 行長目安 | Google guide は明示せず。Prettier 使用時は `printWidth` 既定 80 | Prettier 既定 |

### 2.3 主要スタイル規則

- **クラスセレクタを優先し ID セレクタを避ける**: `id` は詳細度が高く再利用できないため、スタイル付けは `class` で行う（Google guide "ID selectors"）。
- **型セレクタでのクラス修飾を避ける**: `div.error` ではなく `.error` とする（ヘルパークラス等で必要な場合を除く）（Google guide "Type selectors"）。
- **ショートハンドプロパティの活用**: `margin` / `padding` / `font` / `background` 等のショートハンドを、単一値のみ設定する場合でも可能な限り使う（Google guide "Shorthand properties"）。
- **妥当な CSS**: 可能な限り妥当な CSS とし、W3C CSS Validation Service（https://jigsaw.w3.org/css-validator/）で検証する（Google guide "CSS validity"）。
- **宣言順の統一**: Google guide はアルファベット順を推奨（ベンダープレフィクスは無視して並べる）。ただしこれは Google 固有規則であり、プロジェクトの stylelint 設定（例: プロパティグループ順）が存在すればそれが優先される（Google guide "Declaration order"）。
- **アプリ固有プレフィクス（任意）**: 他プロジェクトへ埋め込むコードや大規模プロジェクトでは名前空間としてプレフィクスを付す（`.adw-` 等）（Google guide "Prefixes"）。
- **整形ツール優先**: `.prettierrc*` / `.stylelintrc*` が存在する場合はそれを最優先とする。特に **先頭ゼロ** と **引用符** は Google guide と Prettier 既定が逆になるため、ツール設定の有無で判断する（優先順位: [`conventions-resolution.md`](../../../references/conventions-resolution.md)）。

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| Lint | `npx stylelint "**/*.{css,scss}"` | stylelint（https://stylelint.io/）。設定 `.stylelintrc*`。共有設定 `stylelint-config-standard` |
| 整形 | `npx prettier --write "**/*.{css,scss}"` | Prettier（https://prettier.io/） |
| Sass コンパイル | `npx sass input.scss output.css` | Dart Sass（https://sass-lang.com/dart-sass）。または Vite / webpack 等バンドラ経由 |
| ベンダープレフィクス付与 | Autoprefixer（PostCSS） | https://github.com/postcss/autoprefixer 。対応範囲は Browserslist（https://browsersl.ist/）で指定 |
| 検証 | W3C CSS Validation Service | https://jigsaw.w3.org/css-validator/ |
| 目視検証 | ブラウザ DevTools | 算出スタイル・詳細度・レイアウトのデバッグ |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.stylelintrc*`（`.json` / `.js` / `.yml` 等） | stylelint のルール設定 |
| `.prettierrc*` | Prettier 整形設定 |
| `.editorconfig` | インデント・改行・文字コード（https://editorconfig.org/） |
| `.browserslistrc` / `package.json` の `browserslist` | Autoprefixer 等が参照する対応ブラウザ範囲 |

## 4. イディオム・ベストプラクティス

**命名手法: BEM（Block Element Modifier）**

- BEM は `block__element--modifier` の形式で、要素の役割と状態を名前で表現する広く使われた手法（https://getbem.com/ / https://en.bem.info/methodology/）。例: `.card`（Block）/ `.card__title`（Element）/ `.card--featured`（Modifier）。
- BEM は Google HTML/CSS Style Guide とは **別体系** の命名規約である。両者を混在させず、プロジェクトが BEM を採用しているか（既存クラス名の形式）を確認して従う。未採用なら Google 準拠の意味的 kebab-case 命名（セクション 2.1）を用いる。

**設計**

- **詳細度を低く保つ**: 単一クラスセレクタ中心にし、深いネスト・ID セレクタ・過剰な子孫セレクタを避ける。上書きの連鎖を防ぐ。
- **`!important` を避ける**: 詳細度の破綻を招くため原則使わない（ユーティリティの最終手段等に限定）。
- **CSS カスタムプロパティ（変数）**: 色・余白・タイポグラフィ等のトークンは `:root { --color-primary: #06c; }` のように定義し `var(--color-primary)` で参照する。テーマ切替・一貫性に有効（MDN: https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties）。
- **モダンレイアウト**: 一次元配置は Flexbox、二次元配置は Grid を用いる。`float` ベースのレイアウトは避ける（MDN CSS layout: https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout）。
- **レスポンシブ（モバイルファースト）**: 小画面向けの基本スタイルを土台にし、`@media (min-width: ...)` で大画面向けの指定を積み増す。相対単位（`rem` / `%` / `fr`）を活用する（MDN Responsive design: https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design）。

**Sass（`.scss` / `.sass`）**（https://sass-lang.com/）

- **ネストは浅く**: ネストは 3 階層程度までを目安とする。深いネストは詳細度の肥大と可読性低下を招く（Sass Guidelines: https://sass-guidelin.es/）。
- **変数・mixin・function・placeholder** は kebab-case で命名する（セクション 2.1）。
- 部分ファイル（partial、`_buttons.scss`）に分割し、`@use` / `@forward`（現行のモジュールシステム）で読み込む。`@import` は Dart Sass で非推奨・将来廃止のため、新規では `@use` を用いる。
- `@extend` の乱用を避け、共通化は mixin / placeholder を基本とする。

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| 意図しない上書き（スタイルが効かない） | 詳細度の競合、後勝ちの記述順、ID セレクタの混在 | 詳細度を揃える（単一クラス中心）。DevTools の算出スタイルで勝っている宣言を特定。`!important` で押し切らない |
| ベンダープレフィクス不足 | 手書きプレフィクスの漏れ・陳腐化 | Autoprefixer + Browserslist で自動付与し、手書きプレフィクスは書かない |
| z-index の乱立 | 場当たり的な大きな値、スタッキングコンテキストの誤解 | 値を体系化（トークン / スケール化）。新規スタッキングコンテキスト（`transform` / `opacity` / `position` 等）の生成箇所を把握する |
| ネスト過多（Sass） | セレクタを深くネストしすぎ | 3 階層程度に抑え、詳細度を下げる |
| マジックナンバー | 根拠不明な固定値の散在 | 変数（カスタムプロパティ / Sass 変数）に集約する |

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| Tailwind CSS / Sass / Bootstrap 等（ユーティリティ / プリプロセッサ / UI フレームワーク・ビルドツール） | [frontend-tooling.md](../../../references/frameworks/frontend-tooling.md) |
