# add-design-html 実行手順

環境構築は `setup.md` を参照すること。

## 1. 要件確定

対話モードでは以下を確定する（非対話モードは引数値をそのまま使う）。

| 項目 | 確認内容 | 制約 |
|------|---------|------|
| デザイン名 | kebab-case の英名（例: `warm-paper`） | 予約名 `template` / `default` 不可、既存デザイン名との重複不可 |
| コンセプト | 配色・雰囲気・用途 | — |
| HTML 構造変更 | CSS のみで表現可能か | **既定は CSS のみ**。構造要素の追加が必要な場合のみ HTML ペアを生成 |

既存デザイン名の重複チェックは [`../../../references/design-locations.md`](../../../references/design-locations.md) の探索順序で
`assets/css/*.css` とローカルデザインディレクトリを走査して行う。

## 2. ベースの読み込み

- デフォルト CSS: `${CLAUDE_PLUGIN_ROOT}/assets/css/template.css`（全セクション構成のリファレンス）
- 契約リスト: [`css-contract.md`](css-contract.md)（REQUIRED セレクタの全リスト）
- HTML ペア生成時のみ: `${CLAUDE_PLUGIN_ROOT}/assets/html/template.html`

## 3. CSS の生成

`$SESSION_DIR/workspace/<design-name>.css` を生成する。

設計ガイドライン:

- `template.css` のセクション構成（Reset & Base → レイアウト → 見出し → … → レスポンシブ → プリント）を踏襲すると契約漏れが起きにくい
- `css-contract.md` の REQUIRED セレクタをすべて含める（コピーして配色・装飾を変える進め方を推奨）
- `@media (max-width: 1024px)` のブレークポイント値は変更しない（JS 契約）
- `#lb-overlay` / `#toc-mobile-header` の既定 `display: none` を必ず維持する
- Pygments トークン配色は書かない（変換時に別注入される）。暗背景デザインでは `.highlight` / `pre` の背景色と
  `{{PYGMENTS_CSS}}` の相性に注意（friendly テーマは明背景前提のため、コード領域のみ明背景に保つ選択が安全）

### HTML ペアの生成（構造変更が必要な場合のみ）

`$SESSION_DIR/workspace/<design-name>.html` を生成する。

- `template.html` をベースに、プレースホルダ 6 種（`{{TITLE}}` `{{CSS}}` `{{PYGMENTS_CSS}}` `{{TOC_SIDEBAR}}` `{{BODY_HTML}}` `{{JS_BLOCK}}`）を**すべて維持**する
- 骨格 DOM（`id="wrap"` / `id="main-content"` / `class="doc-title"` / `class="article-body"`）を維持する
- `{{TOC_SIDEBAR}}` は `{{JS_BLOCK}}` より前に置く
- 追加してよいのは装飾目的の構造要素（ヘッダーバー・フッター等）のみ。JS が参照する ID/クラスと衝突する `toc-` / `lb-` プレフィクスの ID を新設しない

## 4. 機械検証

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_css.py" \
  "$SESSION_DIR/workspace/<design-name>.css"
```

HTML ペアがある場合は追加で:

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/add-design-html/validate_html.py" \
  "$SESSION_DIR/workspace/<design-name>.html"
```

- 両方 `RESULT: PASS` を確認する。`[WARN]` は内容を確認し、意図的な省略以外は解消する
- `RESULT: FAIL` の場合は FAIL 行のセレクタ・契約を CSS / HTML に追加して再検証する

## 5. サンプル変換（動作確認）

見出し（H2 複数 + H3）・段落・箇条書き・コードブロック・表・引用・タスクリスト・画像を含む
サンプル MD を `workspace/` に用意し、実変換する。

```bash
"$SESSION_DIR/workspace/.venv/Scripts/python" \
  "${CLAUDE_PLUGIN_ROOT}/references/scripts/convert-html/convert.py" \
  "$SESSION_DIR/workspace/sample.md" \
  "$SESSION_DIR/workspace/sample-<design-name>.html" \
  --css-template "$SESSION_DIR/workspace/<design-name>.css"
```

HTML ペアがある場合は `--html-template "$SESSION_DIR/workspace/<design-name>.html"` も付与する。

- 変換成功と出力 HTML の生成を確認する
- 生成 HTML をユーザーに提示し、デザインの見た目を確認してもらう（対話モード時）

## 6. 配置

[`../../../references/design-locations.md`](../../../references/design-locations.md) の節 4 に従い配置先を判定する。

| モード | CSS 配置先 | HTML ペア配置先 |
|-------|-----------|----------------|
| 開発モード | `<repo_root>/plugins/convert-doc/assets/css/<design-name>.css` | `<repo_root>/plugins/convert-doc/assets/html/<design-name>.html` |
| 利用者モード | `<designs>/css/<design-name>.css` | `<designs>/html/<design-name>.html` |

- 配置先ディレクトリが無ければ作成する
- 判定結果と配置先パスをユーザーに提示し、承認を得てからコピーする（対話モード時）
- 同名ファイルが既にある場合は無確認で上書きしない

## 7. 使い方案内

配置完了後、以下を提示する。

- `convert-html` 実行時に CSS 選択肢として表示されること（複数デザイン存在時）
- `convert-pdf` も同じ CSS 資産を共有するため、PDF 出力にも適用可能なこと
- 明示指定する場合のオプション例: `--css-template "<配置先絶対パス>"`（ペア時は `--html-template` も）

## トラブルシューティング

| 症状 | 対応 |
|------|------|
| `[FAIL] lightbox-js: #lb-overlay has 'display: none' ...` | `#lb-overlay { display: none; ... }` のルールを追加（欠けるとページ読込時に画面が覆われる） |
| `[FAIL] breakpoint: @media (max-width: 1024px) ...` | ブレークポイントを 1024px に戻す（toc-toggle.js の定数と一致必須） |
| 生成 HTML で目次のトグルが効かない | `.toc-collapsed` / `.toc-mobile-open` に transform 等の視覚変化が定義されているか確認 |
| PDF で背景色が消える | `@media print` に `-webkit-print-color-adjust: exact` を追加 |
| 暗背景でコードだけ白浮きする | 意図的な仕様（Pygments 注入 CSS が明背景前提）。コード領域を明背景に保つか、デザイン側で `.highlight` の彩度を調整 |
