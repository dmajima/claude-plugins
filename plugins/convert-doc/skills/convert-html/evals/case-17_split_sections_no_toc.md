# Case 17: Web ページ型 + toc-toggle.js 除外 → 目次なしページ

## 入力

- 入力 MD: H1 + 導入段落 + H2 が 3 つある Markdown
- Web ページ型テンプレート（executive.css + executive.html + `--split-sections`）を使用
- JS 機能の除外選択で「目次」（toc-toggle.js）が除外された

## 期待動作

1. `--js-features` に `toc-toggle.js` を含めずに `convert.py` を実行する（例: `--js-features lightbox.js,scroll-reveal.js`）
2. `toc_enabled` が偽になるため目次 HTML は生成されず、`{{TOC_SIDEBAR}}` は空になる
3. ヒーロー・章番号付き本文セクション・ページフッターは通常どおり生成される
4. デスクトップの目次トグルボタン・モバイルのフローティングボタンも出力されない（toc-toggle.js が DOM を生成しないため）

## 期待出力

- `<aside id="toc-sidebar">` が 0 件
- ページ構成は ヒーロー + 本文セクション 3（章番号 01〜03）+ ページフッター

## 分岐の根拠

`references/scripts/convert-html/convert.py` の main():

> ```python
> toc_enabled = "toc-toggle.js" in selected_js
> ```
> ```python
> # Step 9: 目次処理（目次機能が無効な場合は出力しない。...）
> if not toc_enabled:
>     toc_html = ""
> ```

`references/css-js-selection.md`「Web ページ型テンプレート選択時の注意」:

> 目次が不要な場合は通常の JS 除外選択で `toc-toggle.js` を外せばよい

## 関連ケース

- [case-16_executive_web_template.md](case-16_executive_web_template.md) — 既定（全 JS 機能 = 目次あり）の Web ページ型変換
- [case-04_js_exclude_interactive.md](case-04_js_exclude_interactive.md) — JS 機能の除外選択 UI（本ケースはその選択結果の下流分岐）
