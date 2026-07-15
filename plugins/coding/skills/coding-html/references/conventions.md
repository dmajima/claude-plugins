# HTML 言語プロファイル

> 本プロファイルは「プロジェクト独自規約が存在しない場合のデフォルト」である。プロジェクト設定（`.editorconfig` / Prettier / `CLAUDE.md` 等）が存在する場合の優先順位は [`conventions-resolution.md`](../../../references/conventions-resolution.md) に従う。

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.html`, `.htm` |
| マーカーファイル | 単一のマーカーは持たない（拡張子の出現数で検出）。整形設定として `.editorconfig` / `.prettierrc*`、検証設定として `.htmlvalidate.json` が併存しうる |

**テンプレート形式は本プロファイルの対象外**: `.vue`（Vue SFC）/ `.jsx` `.tsx`（React JSX）/ `.blade.php`（Laravel Blade）/ `.twig` / `.erb` 等のテンプレート構文は素の HTML とは別規約であり、各フレームワークプロファイル（[react.md](../../../references/frameworks/react.md) / [vue.md](../../../references/frameworks/vue.md) / [php-web.md](../../coding-php/references/frameworks/php-web.md)）で扱う。本プロファイルは静的 HTML（`.html` / `.htm`）およびテンプレート内の素の HTML 部分に適用する。

## 2. デファクトスタンダード規約

**準拠規約**: Google HTML/CSS Style Guide（https://google.github.io/styleguide/htmlcssguide.html）

補助的に以下を参照する。

- WHATWG HTML Living Standard（https://html.spec.whatwg.org/multipage/） — 要素のセマンティクス・妥当な入れ子・ブール属性
- WCAG 2.2（https://www.w3.org/TR/WCAG22/） / WAI-ARIA Authoring Practices Guide（https://www.w3.org/WAI/ARIA/apg/） — アクセシビリティ

### 2.1 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| 要素名 | 小文字のみ | `<section>`（`<SECTION>` 不可） |
| 属性名 | 小文字のみ | `maxlength`（`maxLength` 不可） |
| 属性値 | 小文字（テキスト / CDATA を除く。`class` / `id` 識別子は目的を表す kebab-case を推奨） | `type="text"`、`class="main-nav"` |
| id / class | 目的を表す名前を kebab-case で。CSS の命名規則に合わせる（[CSS 規約](../../coding-css/references/conventions.md) 参照） | `id="login-form"`、`class="card-title"` |
| ファイル名 | 小文字 + ハイフン区切り（kebab-case） | `contact-form.html` |

出典: 要素名・属性名・属性値の小文字統一、id / class のハイフン区切りは Google HTML/CSS Style Guide の "Capitalization" / "ID and class name delimiters"。ファイル名の kebab-case は URL の可搬性を踏まえた Web 一般慣行。

### 2.2 インデント・フォーマット

| 項目 | 規定 | 出典 |
|------|------|------|
| インデント | スペース 2 個（タブ不可・混在不可） | Google guide "Indentation" |
| 属性値の引用符 | ダブルクォート `"..."` | Google guide "HTML quotation marks" |
| 大文字小文字 | 要素名・属性名・属性値すべて小文字 | Google guide "Capitalization" |
| ブール属性 | 値を省略し属性名のみ記述（`<input required>`、`<option selected>`） | HTML Living Standard "Boolean attributes"（Google guide 固有の規定ではない） |
| 任意タグの省略 | **省略しない**（`</li>` `</p>` `<tbody>` 等をすべて明示する） | Google guide "Optional tags" は省略を任意推奨するが、本プロファイルは可読性・差分の明瞭さを優先し非省略をデフォルトとする |
| 行長目安 | 規定なし（Google guide は HTML の行折り返しを任意とする）。Prettier 使用時は `printWidth` 既定 80 | Google guide "HTML line-wrapping" / Prettier 既定 |
| 末尾空白 | 除去する | Google guide "Trailing whitespace" |
| 文字コード | UTF-8（BOM なし） | Google guide "Encoding" |

### 2.3 主要スタイル規則

- **HTML5 を使用**: 文書型は `<!DOCTYPE html>`。XHTML は使用しない（Google guide "Document type"）。
- **妥当な HTML**: 可能な限り妥当なマークアップとし、W3C / Nu バリデータで検証する（Google guide "HTML validity"）。
- **目的に沿った要素選択（セマンティクス）**: 見出しは見出し要素、段落は `p`、リンクは `a`、操作は `button` 等、要素本来の目的で使う（Google guide "Semantics"）。詳細はセクション 4。
- **構造・表現・振る舞いの分離**: マークアップ（構造）・CSS（表現）・JavaScript（振る舞い）を分離し、インラインの `style` 属性・`on*` ハンドラを避ける（Google guide "Separation of concerns"）。
- **type 属性の省略**: スタイルシートとスクリプトの `type` は省略する（`<link rel="stylesheet" href="...">` / `<script src="..."></script>`）（Google guide "type attributes"）。
- **実体参照を多用しない**: UTF-8 前提のため `&mdash;` 等は不要。`<`・`&` など HTML 上で意味を持つ文字と不可視文字のみ実体参照を使う（Google guide "Entity references"）。
- **代替コンテンツ**: 画像・動画等には代替手段（`alt`、字幕・トランスクリプト）を提供する（Google guide "Multimedia fallback"）。

**文書構造の必須要素**:

- `<!DOCTYPE html>` を文書先頭に置く。
- `<html lang="ja">` のように `lang` 属性で主要言語を指定する（読み上げ・翻訳の基礎。WCAG 3.1.1 Language of Page）。
- `<meta charset="utf-8">` を `<head>` の先頭付近に置く。
- レスポンシブ対応のため `<meta name="viewport" content="width=device-width, initial-scale=1">` を指定する（MDN Viewport meta tag: https://developer.mozilla.org/en-US/docs/Web/HTML/Viewport_meta_tag）。

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| 検証（オフライン / CI） | `npx html-validate "**/*.html"` | html-validate（https://html-validate.org/）。設定 `.htmlvalidate.json` |
| 検証（オンライン） | W3C Markup Validation Service / Nu Html Checker | https://validator.w3.org/ ・ https://validator.w3.org/nu/ |
| 整形 | `npx prettier --write "**/*.html"` | Prettier（https://prettier.io/）。HTML 整形に対応 |
| 目視・DOM 検証 | ブラウザ DevTools | 要素検査、Lighthouse でのアクセシビリティ / パフォーマンス監査 |

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `.editorconfig` | インデント・改行・文字コード（EditorConfig: https://editorconfig.org/） |
| `.prettierrc*` | Prettier 整形設定（`printWidth` / `tabWidth` / `singleAttributePerLine` 等） |
| `.htmlvalidate.json` | html-validate のルール設定 |

## 4. イディオム・ベストプラクティス

**セマンティック HTML**（WHATWG HTML Living Standard: https://html.spec.whatwg.org/multipage/）

- ページ領域を意味に沿った要素で構成する: `header`（導入・ロゴ）/ `nav`（主要ナビゲーション）/ `main`（主要コンテンツ、1 ページ 1 個）/ `article`（自己完結した内容）/ `section`（見出しを持つ意味的まとまり）/ `aside`（補足）/ `footer`（脚部）。
- 見出しは `h1`〜`h6` を階層順に使い、レベルを飛ばさない（`h1` の次に `h3` 等を避ける）。装飾目的で見出しレベルを選ばない。
- 遷移は `a`（`href` を持つリンク）、操作・送信は `button`。`<div onclick>` でクリック可能要素を代替しない（キーボード操作・フォーカス・支援技術対応が失われる）。
- リスト・表・フォームは対応する要素（`ul` / `ol` / `li`、`table` / `thead` / `tbody`、`form` / `fieldset` / `label`）で構造化する。

**アクセシビリティ**（WCAG 2.2: https://www.w3.org/TR/WCAG22/）

| 対象 | 規則 |
|------|------|
| 画像 | `img` に `alt` を必須とする。意味を持つ画像は内容を説明し、装飾画像は `alt=""` とする（WCAG 1.1.1 Non-text Content） |
| フォーム | 各入力を `<label for="id">` または `label` で囲んで関連付ける（WAI Forms Tutorial: https://www.w3.org/WAI/tutorials/forms/labels/、WCAG 1.3.1 / 4.1.2） |
| ARIA | セマンティック要素・ネイティブ属性で表現できる場合は ARIA を使わない。標準要素で表現できない場合の補完としてのみ role / state / property を付す（"First Rule of ARIA Use"、Using ARIA: https://www.w3.org/TR/using-aria/） |
| キーボード操作 | すべての操作をキーボードで実行可能にする。ネイティブの `button` / `a` / `input` はこれを標準で満たす（WCAG 2.1.1 Keyboard） |

**その他**

- 1 ページに `main` は 1 個、`h1` は原則 1 個とする。
- `id` はページ内で一意にする（重複は不正であり、スクリプト・ラベル参照を壊す）。
- 表示専用の情報は CSS へ、動的挙動は JavaScript へ委ね、HTML は構造に集中させる。

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| タグの閉じ忘れ・入れ子不正 | `</div>` の欠落、`p` 内へのブロック要素配置、`ul` 直下の `li` 以外の配置 等 | バリデータ（html-validate / Nu）で検出し、各要素の内容モデルに従う |
| id 重複 | 同一 `id` を複数要素に付与 | id を一意化し、共通スタイルは `class` を使う |
| フォーム関連付け漏れ | `label` の `for` と input の `id` の不一致、`label` 未設定 | `for` / `id` を一致させるか `label` で囲む |
| 代替テキスト欠如 | `img` の `alt` 未指定 | 意味のある `alt` を付与し、装飾画像は `alt=""` |
| インラインスタイル / ハンドラの乱用 | `style=` / `onclick=` の多用 | CSS クラス・外部 JavaScript（`addEventListener`）へ分離 |
| 文字化け | `meta charset` 未指定・非 UTF-8 保存 | UTF-8（BOM なし）で保存し `<meta charset="utf-8">` を明示 |

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| React / Next.js（JSX / TSX テンプレート） | [react.md](../../../references/frameworks/react.md) |
| Vue / Nuxt（SFC テンプレート `.vue`） | [vue.md](../../../references/frameworks/vue.md) |
| Laravel / Symfony / WordPress（Blade / Twig 等テンプレートエンジン） | [php-web.md](../../coding-php/references/frameworks/php-web.md) |
