# CSS レビュー観点プロファイル

CSS（`.css` / `.scss` / `.sass`）コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約（`.stylelintrc*` / `.prettierrc*` / `.editorconfig` / 既存の命名体系）が存在する場合はそちらを最優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.css` / `.scss`（SCSS 構文）/ `.sass`（インデント構文） |
| マーカーファイル | 単一マーカーは持たない（拡張子で検出）。`.stylelintrc*` / `.prettierrc*`、`package.json` の依存に `sass` / `stylelint` / `postcss` / `autoprefixer` があれば当該ツールチェーンと判断 |
| プリプロセッサ判別 | `.scss` / `.sass` = Sass、`postcss.config.*` = PostCSS パイプライン、`tailwind.config.*` = Tailwind |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- Google HTML/CSS Style Guide（命名・整形・詳細度・宣言順）
- BEM（Block Element Modifier）— 命名手法。Google スタイルとは別体系のため、プロジェクトが採用しているか既存クラス名で確認して従う
- Sass Guidelines / Sass 公式 — Sass の運用・命名・モジュールシステム
- MDN Web Docs — レイアウト（Flexbox / Grid）・カスタムプロパティ・レスポンシブ設計
- WCAG 2.x（W3C）— アクセシビリティ（コントラスト・フォーカス・モーション）

### 2.1 命名・整形の要点（デフォルト基準の要約）

| 対象 | デフォルト規則 | 備考 |
|------|--------------|------|
| クラス名 | kebab-case・目的ベース（`.video-title`） | BEM 採用時は `block__element--modifier` を優先 |
| カスタムプロパティ / Sass 識別子 | kebab-case（`--color-primary` / `$brand-color` / `%visually-hidden`） | 用途がわかる名前 |
| インデント・宣言 | スペース 2 個・1 行 1 宣言・宣言末尾セミコロン | `.editorconfig` があれば優先 |
| 0 値の単位 | 省略（`margin: 0;`） | Google guide "0 and units" |
| 16 進カラー | 小文字・可能なら 3 文字表記（`#ebc`） | Google guide "Hexadecimal notation" |
| 先頭ゼロ・引用符 | Google guide は先頭ゼロ省略・単一引用符 | **Prettier 既定は逆**（付与・ダブル）。ツール設定を優先 |
| 宣言順 | Google guide はアルファベット順（プレフィクス無視） | stylelint のグループ順設定があれば優先 |

## 3. レビュー観点

### 3.1 設計・詳細度【担当: web-designer】

- [ ] **`!important` の濫用** — 詳細度の破綻・上書き合戦を招く。ユーティリティの最終手段等に限定されているか
- [ ] **ID セレクタでのスタイル付け**（`#header { ... }`）— 詳細度が過剰で再利用不能。class セレクタに置換すべき
- [ ] **インラインスタイル**（`style="..."`）の新規追加 — 詳細度が最強で上書き困難・CSP 阻害・再利用不能
- [ ] 深い結合子・過剰な子孫セレクタ（`.a .b .c .d` の長い連鎖）による詳細度の肥大
- [ ] 型セレクタでの不要なクラス修飾（`div.error` → `.error`。ヘルパー等で必要な場合を除く）
- [ ] 記述順・詳細度の競合で「効かない CSS」を生む設計（後勝ちに依存した脆い上書き）
- [ ] ユニバーサルセレクタ `*` や広範な要素セレクタへの重いプロパティ指定（全体波及・継承事故）
- [ ] リセット / ノーマライズと個別スタイルの二重管理・打ち消し合い
- [ ] `@media` / `@supports` 内での不用意な詳細度引き上げ（外側との上書き競合）

### 3.2 命名（BEM）【担当: web-designer】

- [ ] **プロジェクトの既存命名体系（BEM / kebab-case / CSS Modules / ユーティリティ）との整合を最優先**する
- [ ] BEM 採用プロジェクトで `block__element--modifier` 形式から逸脱していないか（`__` / `--` の混同、camelCase 混入、多重要素連結）
- [ ] 見た目ベースの命名（`.red-text` / `.grid-3col`）の散在 — 目的・役割ベース（`.alert` / `.gallery`）を優先
- [ ] クラス名の kebab-case 逸脱（`.videoTitle` / `.video_title`）— 未採用命名体系では Google 準拠の意味的 kebab-case
- [ ] カスタムプロパティ・Sass 変数・mixin・placeholder の命名一貫性（`--color-primary` / `$brand-color` / `%visually-hidden`）
- [ ] ファイル名・partial（`_buttons.scss`）の kebab-case 逸脱、命名とディレクトリ構成の不一致

### 3.3 レスポンシブ・レイアウト【担当: web-designer】

- [ ] **固定幅（`width: 960px` 等）によるモバイル対応漏れ** — 相対単位（`%` / `rem` / `fr` / `max-width`）で流動化されているか
- [ ] メディアクエリのブレークポイントがプロジェクト内で一貫しているか（根拠不明な px 値の乱立）
- [ ] モバイルファースト（`min-width` 積み増し）と `max-width` 方式の混在による指定の打ち消し合い
- [ ] **`float` ベースの新規レイアウト** — 一次元は Flexbox、二次元は Grid を用いる
- [ ] **`position: absolute` の濫用** によるレイアウト構築（レスポンシブ破綻・重なり事故の温床）
- [ ] ビューポート単位（`vh` / `vw`）のモバイルブラウザ UI バー・スクロールバー考慮漏れ
- [ ] `overflow` による小画面でのコンテンツ見切れ・意図しない横スクロール発生

### 3.4 アクセシビリティ【担当: web-designer】

- [ ] **`outline: none` 単独でのフォーカスリング除去** — キーボード操作不能。`:focus-visible` で代替スタイルを与えているか
- [ ] テキストと背景の**コントラスト比不足**（WCAG AA: 通常テキスト 4.5:1 / 大テキスト 3:1）
- [ ] **`prefers-reduced-motion` 未考慮のアニメーション**（前庭障害・乗り物酔いへの配慮欠如）
- [ ] `display: none` / `visibility: hidden` による支援技術からの意図しない読み上げ除外
- [ ] 意味を持つコンテンツを CSS（`content` / 擬似要素 / 背景画像）のみで表現し支援技術に伝わらない
- [ ] `px` 固定フォントサイズによるユーザーのブラウザ拡大阻害（`rem` 推奨）・タップ領域の過小
- [ ] 色のみで状態（エラー / 成功 / 必須）を伝達し、色覚特性のあるユーザーに区別不能
- [ ] スクリーンリーダー専用テキストの隠蔽手法の誤り（`display: none` は読み上げも消える。`.visually-hidden` パターンを使う）

### 3.5 保守性・重複【担当: web-designer】

- [ ] **マジックナンバー**（説明のない `px` 値・`z-index: 9999` 等）— デザイントークン / CSS 変数への集約
- [ ] **ハードコードされた色**（`#3498db` の直書き散在）— カスタムプロパティ / Sass 変数で一元管理
- [ ] **`z-index` の無秩序なエスカレーション**（`9999` / `99999` の場当たり）— スケール体系化・スタッキングコンテキスト把握
- [ ] 重複した宣言ブロック・コピペされたスタイル群 — 共通化（クラス / mixin / placeholder）
- [ ] ショートハンドの意図しない上書き（`background: red;` が既存 `background-image` を消す等）
- [ ] コメントアウトされた死んだスタイルの残留・対応 HTML 削除済みの未使用スタイル
- [ ] **セレクタとマークアップの不一致でスタイルが無言で未適用**（CSS 側のクラス名・ID が対象コンポーネント/テンプレートの実際の class・要素構造と一致せず、意図したスタイルが当たらない。差分でマークアップと CSS の双方が変わった場合は対応関係を確認する。「未使用スタイル」＝死んだコードとは区別される機能不具合）
- [ ] グローバルセレクタ（要素・`body` 直下）への個別スタイル付与によるスコープ汚染
- [ ] 継承で足りる箇所の冗長な再指定（`font-family` / `color` の全要素個別指定 等）

### 3.6 パフォーマンス【担当: web-designer / performance-reviewer】

- [ ] **`top` / `left` / `width` / `height` のアニメーション** — レイアウト再計算を誘発。`transform` / `opacity` へ置換
- [ ] レイアウトスラッシング（強制同期レイアウトを誘発する CSS 起因の設計）
- [ ] 巨大・過剰に複雑なセレクタ（ユニバーサル `*` + 属性 + 擬似の多段組み合わせ）
- [ ] 高頻度で再描画される要素への高コストプロパティ（`box-shadow` / `filter: blur()` 等）の多用
- [ ] `@import` による CSS の直列読み込み（レンダリングブロック）
- [ ] `will-change` の張りっぱなし（メモリ消費）・未使用 CSS 同梱によるバンドル肥大
- [ ] `@font-face` の `font-display` 未指定によるテキスト描画ブロック（FOIT）

### 3.7 Sass/SCSS【担当: web-designer】

- [ ] **ネスト深度 3 階層超** — 詳細度肥大・可読性低下。フラット化を検討
- [ ] **`@extend` の濫用** — 予期しないセレクタ結合・出力肥大。共通化は mixin / placeholder を基本に
- [ ] 変数の使い分け（テーマ切替・実行時変更が要る値は CSS カスタムプロパティ、ビルド時定数は Sass 変数）
- [ ] `@import`（Dart Sass で非推奨・将来廃止）の新規使用 — `@use` / `@forward` へ
- [ ] partial 分割・命名（`_buttons.scss`）の規約整合、mixin の副作用・グローバル変数汚染
- [ ] ループ（`@each` / `@for`）による大量セレクタ生成での CSS 出力肥大

### 3.8 ブラウザ互換・その他【担当: web-designer / linter-static-analysis】

- [ ] **手書きベンダープレフィクス**（`-webkit-` / `-moz-` の直書き）— Autoprefixer + Browserslist 前提か確認。陳腐化リスク
- [ ] 対応ブラウザ範囲（`.browserslistrc`）を超える新機能（`:has()` / `@container` 等）のフォールバック欠如
- [ ] 整形規約との不整合 — **先頭ゼロ・引用符は Google guide と Prettier 既定が逆**になるため、ツール設定の有無で判断
- [ ] 宣言順・空セミコロン・0 への冗長な単位付与等、静的検出可能な逸脱
- [ ] W3C 妥当性（不正なプロパティ値・タイポ `dispaly` / 存在しない値）
- [ ] 論理プロパティ（`margin-inline` 等）未使用による多言語・RTL レイアウト非対応（国際化要件がある場合）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| フォーカスリング除去（`outline: none` 単独） | High〜Medium | キーボード操作不能・a11y 重大（実適用範囲・対象ユーザ影響で最終判定は severity-ranking に従う） |
| コントラスト比不足（WCAG AA 未満） | High〜Medium | 可読性・アクセシビリティ違反（適用範囲・比率の乖離度で最終判定は severity-ranking に従う） |
| 色のみでの状態伝達（色覚特性への配慮欠如） | High〜Medium | 状態が区別不能・a11y |
| 固定幅によるモバイル対応漏れ | High〜Medium | 主要デバイスで表示崩壊 |
| `!important` の濫用 | Medium〜High | 詳細度破綻・上書き合戦の連鎖 |
| ID セレクタ / インラインスタイルでのスタイル付け | Medium〜High | 詳細度過剰・再利用不能・上書き困難 |
| `top`/`left` アニメーション（高頻度パス） | Medium〜High | 再描画コスト・カクつき |
| `z-index` 無秩序エスカレーション | Medium | 重なり事故・保守困難 |
| セレクタとマークアップ不一致でスタイル未適用（デッドCSS 化） | Medium | 意図したスタイルが当たらない機能不具合 |
| ハードコード色・マジックナンバー | Medium〜Low | 一貫性欠如・変更漏れリスク |
| `float` 新規レイアウト・`position:absolute` 濫用 | Medium〜Low | 保守性・レスポンシブ耐性 |
| Sass ネスト過多（3 階層超）・`@extend` 濫用 | Medium〜Low | 詳細度肥大・出力肥大 |
| 命名規約逸脱（BEM / kebab-case） | Medium〜Low | 可読性・規約整合 |
| 手書きベンダープレフィクス | Low〜Medium | 陳腐化（Autoprefixer で解決） |
| `font-display` 未指定（FOIT） | Low〜Medium | 初期テキスト描画のブロック |
| 宣言順・先頭ゼロ・引用符等の整形逸脱 | Low | 整形ツールで解決 |

### NG / OK 例（アクセシビリティ: フォーカス可視性）

```css
/* NG: フォーカスリングを一律除去 — キーボード利用者が現在位置を見失う */
button:focus {
  outline: none;
}

/* OK: マウス操作時のみ抑制し、キーボード操作には可視フォーカスを与える */
button:focus-visible {
  outline: 2px solid var(--color-focus);
  outline-offset: 2px;
}
```

## 5. フレームワーク観点

差分に以下の FW / ツールチェーンが関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| Tailwind CSS（`tailwind.config.*` / `@tailwind` ディレクティブ / ユーティリティクラス多用） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |
| Bootstrap（`bootstrap` 依存 / `.container` `.row` `.col-*` 等のグリッドクラス） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |
| Sass / PostCSS / Autoprefixer ツールチェーン（`sass` / `postcss` / `autoprefixer` 依存） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| Lint | `npx stylelint "**/*.{css,scss}"` | エラー内容に応じて Medium〜High（規約逸脱の重大度による） |
| 整形チェック | `npx prettier --check "**/*.{css,scss}"` | 差分あり = Low〜Medium |
| Sass コンパイル | `npx sass --no-source-map <入力>.scss <出力>.css` | コンパイルエラー = High（ビルド破壊） |
| 妥当性検証 | W3C CSS Validation Service（https://jigsaw.w3.org/css-validator/） | 不正宣言 = Medium |
