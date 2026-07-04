# Case 16: executive.css 選択 → Web ページ型ペアリング適用

## 入力

- 入力 MD: H1 + 導入段落 + H2 が 3 つある Markdown
- 対話モード（`/convert-html` または自然言語依頼）
- CSS 選択 UI で `executive.css` を選択（または「経営者向けの資料にして」「LP 風にして」等の依頼）

## 期待動作

1. CSS 合算検出で `template.css` と `executive.css` の 2 件が見つかり、`AskUserQuestion` で選択 UI を表示する（executive の description には「Web ページ型（経営者向け・LP 風）」の説明を含める）
2. `executive.css` が選択されたら、ペアリング規則（`references/css-js-selection.md`）に従い以下を **すべて** 付与して `convert.py` を実行する:
   - `--css-template "<executive.css の絶対パス>"`
   - `--html-template "<executive.html の絶対パス>"`
   - `--split-sections`
3. JS 機能は既定どおり全機能を含める（`toc-toggle.js` = サイドバー/ドロワー目次、`lightbox.js`、`scroll-reveal.js`。除外の対話選択は通常どおり行ってよい）
4. 生成 HTML は LP 風の Web ページ構造になる:
   - 目次サイドバー（`#toc-sidebar`: toc-toggle.js とペア。executive トンマナのスタイルが当たる）
   - ヒーローヘッダー（`.hero`: ネイビー背景にタイトル + 導入段落のサブタイトル）
   - H2 ごとの全幅セクション（`.content-section`: 章番号 `.section-no`（01, 02, ...）+ キーメッセージ見出し + `.section-body`。背景は白/オフホワイトの交互）
   - スリムなページフッター（`.page-footer`: ドキュメントタイトル 1 行）

## 期待出力

- `<aside id="toc-sidebar">` が 1 件、`<header class="hero">` が 1 件、`<section class="content-section">` が 3 件（章番号 01〜03）、`<footer class="page-footer">` が 1 件生成される
- 各本文セクションには見出し id を流用した `aria-labelledby` が付く

## 分岐の根拠

`references/css-js-selection.md`「CSS と HTML 骨格のペアリング」表:
> `executive.css` → `executive.html` の絶対パス + `--split-sections` + JS は既定どおり全機能 / Web ページ型

## 関連ケース

- [case-02_css_multi_interactive.md](case-02_css_multi_interactive.md) — CSS 複数時の選択 UI（本ケースはその選択結果の下流分岐）
- [case-10_no_h2_no_toc.md](case-10_no_h2_no_toc.md) — H2 なしの場合、セクション分割ではヒーロー +（リード文があれば）リードセクションのみになる
- [case-17_split_sections_no_agenda.md](case-17_split_sections_no_agenda.md) — アジェンダセクションの抑止
