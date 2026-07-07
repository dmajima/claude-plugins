# デザイン CSS のセレクタ契約

新デザイン CSS が満たすべき契約の全リスト。HTML 構造（`template.html`）・変換処理（`convert.py`）・
JS 機能（`toc-toggle.js` / `lightbox.js`）は全デザイン共通のため、これらが参照する
セレクタと挙動前提を新 CSS も維持する必要がある。

`validate_css.py` は本契約の REQUIRED 項目を機械検証する。RECOMMENDED 項目は警告のみ。

## 1. REQUIRED（欠落すると FAIL・配置禁止）

### 1.1 骨格（template.html が常時出力する構造）

| セレクタ | 由来 |
|---------|------|
| `#wrap` | ページ全体ラッパー |
| `#main-content` | メインコンテンツ領域 |
| `.doc-title` | ドキュメントタイトル表示 |
| `.article-body` | Markdown 本文コンテナ |

### 1.2 目次 JS 契約（toc-toggle.js）

| セレクタ | 由来・要件 |
|---------|-----------|
| `#toc-sidebar` | convert.py が出力する目次サイドバー。JS の起点（無ければ JS は何もしない） |
| `#toc-toggle-btn` | JS が生成するデスクトップ用トグルボタン。配置・可視性は CSS が担う |
| `#toc-mobile-header` | JS が生成するモバイルヘッダー。**既定 `display: none` 必須**（無いとデスクトップで常時表示される） |
| `#toc-hamburger-btn` | JS が生成するハンバーガーボタン |
| `#toc-mobile-overlay` | JS が生成するモバイル用オーバーレイ |
| `.toc-collapsed` | JS がトグルで付与する折りたたみ状態。CSS 側に視覚変化（transform 等）が無いとトグルが機能しない |
| `.toc-mobile-open` | JS が付与するモバイルドロワー展開状態 |
| `.active` | JS が `#toc-mobile-overlay` に付与する表示状態（`display: block` 等） |

### 1.3 ライトボックス JS 契約（lightbox.js）

| セレクタ | 由来・要件 |
|---------|-----------|
| `#lb-overlay` | JS が生成する全画面オーバーレイ。**既定 `display: none` 必須**（無いとページ読込時に画面全体が覆われる） |
| `#lb-box` | 拡大画像コンテナ |
| `#lb-close` | 閉じるボタン |
| `#lb-hint` | 操作ヒント表示 |

### 1.4 ブレークポイント契約

| 契約 | 要件 |
|------|------|
| `@media (max-width: 1024px)` | toc-toggle.js の `MOBILE_BREAKPOINT = 1024` と**一致必須**。CSS 側だけ境界を変えると、JS のデスクトップ/モバイル切替とレイアウトが desync する |

## 2. RECOMMENDED（欠落すると WARN・見た目品質に影響）

### 2.1 Markdown 変換出力の要素

`h1`〜`h6`, `p`, `a`, `img`, `ul`, `ol`, `li`, `blockquote`, `code`, `pre`, `hr`,
`table`, `th`, `td`, `kbd`, `dl`, `dt`, `dd`

### 2.2 convert.py が固定名で生成するクラス

| クラス | 生成元 |
|-------|--------|
| `.table-scroll` | テーブルの横スクロールラッパー（自動挿入） |
| `.highlight` | コードブロックのコンテナ（codehilite） |
| `.mermaid-figure` / `.mermaid-error` | mermaid 図の図版コンテナ / 取得失敗表示 |
| `.task-list-item` | GFM タスクリスト |

補足: `template.css` には `.footnote` のスタイルも存在するが、現行の `convert.py` は
markdown の `footnotes` 拡張を有効化しておらず生成されない（予約スタイル）。契約対象外。

### 2.3 印刷 / PDF 対応

| 契約 | 理由 |
|------|------|
| `@media print` ブロック | convert-pdf は同じ CSS で Chromium 印刷するため、無いと PDF 品質が崩れる |
| `print-color-adjust: exact`（`-webkit-` 付き含む） | 背景色・シンタックス配色を PDF に残す |
| print 内で `#toc-sidebar` の静的化・`#toc-toggle-btn` / `#toc-mobile-header` / `#toc-mobile-overlay` の非表示 | 画面用 UI の印刷混入防止 |

## 3. 変更してはならないもの（CSS 以外）

- Pygments トークン配色は CSS に書かない（`{{PYGMENTS_CSS}}` として変換時に別注入される）。
  コードブロックの「コンテナ装飾」のみ `.highlight` / `pre` で定義する
- JS ファイル・`features.json` を変更しない（デザインは JS に不干渉）
- mermaid SVG 内部のフォントサイズは CSS で制御できない（convert.py が SVG に直接注入）。
  `.mermaid-figure svg` の外形（width / max-width）のみ調整可能

## 4. 検証コマンド

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_css.py" \
  "<design.css>"
```

`RESULT: PASS` 以外のデザインを配置してはならない。
