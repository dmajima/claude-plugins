#!/usr/bin/env python3
"""
convert.py - Markdown to self-contained HTML converter
Usage: python convert.py <input.md> [output.html] [--title TITLE] [--css-template PATH]

Dependencies: markdown, Pygments, rcssmin, rjsmin, Pillow
"""

import argparse
import base64
import html as html_lib
import io
import json
import mimetypes
import os
import re
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from typing import Optional

# 画像圧縮: このサイズを超えるローカル画像は埋め込み前に圧縮する
IMAGE_COMPRESS_THRESHOLD = 200 * 1024  # 200 KB


def has_background_in_init(diagram_code: str) -> bool:
    """Return True if the mermaid diagram code already specifies background in an init directive.
    例: %%{init: {'themeVariables': {'background': '#ffffff'}}}%%
    """
    pattern = re.compile(r'%%\{.*?%%', re.DOTALL)
    return any('background' in m.group().lower() for m in pattern.finditer(diagram_code))


def fetch_mermaid_svg(diagram_code: str, retries: int = 3, delay: float = 2.0) -> str:
    """Convert mermaid diagram to SVG via mermaid.ink API (with retry)."""
    mermaid_config = {"theme": "default"}
    # init ディレクティブで background が指定されていない場合は themeVariables で白背景を適用
    if not has_background_in_init(diagram_code):
        mermaid_config["themeVariables"] = {"background": "#ffffff"}
    graph_def = {"code": diagram_code, "mermaid": mermaid_config}
    encoded = base64.urlsafe_b64encode(json.dumps(graph_def).encode()).decode().rstrip("=")
    url = f"https://mermaid.ink/svg/{encoded}"
    last_err = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "convert-html/1.0"})
            with urllib.request.urlopen(req, timeout=20) as resp:
                ctype = resp.headers.get("Content-Type", "")
                if "image/svg+xml" not in ctype and "text/xml" not in ctype:
                    raise ValueError(f"unexpected Content-Type: {ctype}")
                return resp.read().decode("utf-8")
        except Exception as e:
            last_err = e
            if attempt < retries - 1:
                time.sleep(delay)
    return (
        f'<div class="mermaid-error">Mermaid変換エラー ({retries}回試行): '
        f"{html_lib.escape(str(last_err))}"
        f"<br><pre>{html_lib.escape(diagram_code)}</pre></div>"
    )


def compress_image_bytes(img_path: Path, mime: str) -> Optional[bytes]:
    """Return compressed image bytes using Pillow, or None if unavailable/unsupported.
    JPEG: re-encoded at quality=75 with optimize flag.
    PNG:  saved with optimize flag (lossless, but removes metadata).
    Other formats are not compressed.
    """
    try:
        from PIL import Image
    except ImportError:
        return None
    try:
        with Image.open(img_path) as img:
            buf = io.BytesIO()
            if mime == "image/jpeg":
                rgb = img.convert("RGB") if img.mode not in ("RGB", "L") else img
                rgb.save(buf, format="JPEG", quality=75, optimize=True)
            elif mime == "image/png":
                img.save(buf, format="PNG", optimize=True)
            else:
                return None
            return buf.getvalue()
    except Exception:
        return None


def _is_within(parent: Path, child: Path) -> bool:
    """Return True if `child` resolves to a path inside (or equal to) `parent`."""
    try:
        parent_r = parent.resolve()
        child_r = child.resolve()
    except OSError:
        return False
    return child_r == parent_r or parent_r in child_r.parents


def embed_image(src: str, base_dir: Path) -> str:
    """Embed a local image as base64 data URI.
    Images over IMAGE_COMPRESS_THRESHOLD bytes are compressed before encoding.
    Returns original src if the image is remote, not found, or escapes base_dir.
    """
    if src.startswith("data:") or src.startswith("http://") or src.startswith("https://"):
        return src
    candidate = base_dir / src
    if candidate.exists() and _is_within(base_dir, candidate):
        img_path = candidate
    else:
        # `src` が絶対パス等で base_dir 外を指す場合は埋め込まずに元の src を返す
        return src
    mime, _ = mimetypes.guess_type(str(img_path))
    if not mime:
        mime = "image/png"
    with open(img_path, "rb") as f:
        raw = f.read()
    if len(raw) > IMAGE_COMPRESS_THRESHOLD:
        compressed = compress_image_bytes(img_path, mime)
        if compressed:
            raw = compressed
    return f"data:{mime};base64,{base64.b64encode(raw).decode()}"


def preprocess_strikethrough(md_text: str) -> str:
    """Convert ~~text~~ to <del>text</del> (GFM strikethrough, not in python-markdown)."""
    return re.sub(r"~~(.+?)~~", r"<del>\1</del>", md_text)


def preprocess_task_lists(md_text: str) -> str:
    """Convert GFM task list items (`- [ ]` / `- [x]`) into HTML checkbox markup.

    python-markdown's core list extension treats the literal "[ ]" as plain text,
    so we rewrite the list marker *inline* before markdown conversion.  The
    resulting list item is rendered as a real <li>, and the <input> tag inside
    it bubbles up through markdown unchanged because attribute-less HTML tags
    are passed through.  The ``.task-list-item`` class is added for CSS hooks
    (e.g. to remove the bullet marker and left-align with the checkbox).
    """
    def _sub(match: "re.Match[str]") -> str:
        indent, marker, state, rest = match.group(1), match.group(2), match.group(3), match.group(4)
        checked = ' checked=""' if state.lower() == "x" else ""
        return (
            f'{indent}{marker} <span class="task-list-item">'
            f'<input type="checkbox" disabled{checked}> {rest}</span>'
        )

    return re.sub(
        r"^([ \t]*)([-*+])\s+\[([ xX])\]\s+(.*)$",
        _sub,
        md_text,
        flags=re.MULTILINE,
    )


def remove_inline_toc(md_text: str) -> str:
    """Remove hand-written TOC sections (## 目次 heading + content) from markdown body.
    These are replaced by the auto-generated right sidebar TOC.
    """
    # 「## 目次」見出しから次のH2見出しまで（またはファイル末尾まで）を削除
    return re.sub(
        r"^##\s+目次\s*\n.*?(?=^##\s|\Z)",
        "",
        md_text,
        flags=re.MULTILINE | re.DOTALL,
    )


def strip_toc_links(toc_html: str) -> str:
    """Remove <a href="..."> wrappers from TOC HTML, keeping text only."""
    return re.sub(r"<a[^>]+>(.*?)</a>", r"\1", toc_html, flags=re.DOTALL)


def postprocess_svg(svg: str, background: Optional[str] = "#ffffff") -> str:
    """Post-process mermaid SVG to prevent text clipping and apply background color.

    mermaid.ink が返す SVG には以下の問題がある:

    1. テキストが foreignObject に収まらずクリップされる（特に ER 図・日本語ラベル）
       原因: SVG 内部の <style> が高 specificity の ID セレクタ
             (#mermaid-svg { font-size: 16px }) でフォントを指定しており、
             さらに <div> の inline style に line-height: 1.5 が設定されている。
             16px × 1.5 = 24px が foreignObject の height="21"～"24" をぴったり
             埋めるか超え、日本語フォントの大きなメトリクスで溢れる。
             外部 CSS (.mermaid-figure svg { font-size: 14px }) では
             ID セレクタ (specificity 1,0,0) に負けて効果がない。
       対策: SVG 末尾に <style> ブロックを直接注入し、!important で
             foreignObject 内 div のフォントサイズと行高を上書きする。
             また overflow:visible を設定して万が一の場合も可視化する。

    2. viewBox の宣言寸法が実コンテンツより小さくエッジ付近でクリップされる
       対策: viewBox に PAD px のパディングを加えてコンテンツを収める。

    3. ルート SVG に背景色がない（透過）
       原因: themeVariables.background は mermaid.ink の SVG 出力に反映されない。
             SVG 内部 CSS のテーマ変数として設定されるが、背景矩形は挿入されない。
       対策: 拡張後の viewBox 全体をカバーする <rect fill="..."/> を SVG 先頭に直接注入する。
             background=None を指定した場合（元の図に背景指定がある場合など）は注入しない。
    """
    PAD = 40

    # 1. Expand viewBox
    def expand_viewbox(m):
        try:
            x = float(m.group(1))
            y = float(m.group(2))
            w = float(m.group(3))
            h = float(m.group(4))
            return (
                f'viewBox="{x - PAD} {y - PAD} '
                f'{w + PAD * 2} {h + PAD * 2}"'
            )
        except ValueError:
            return m.group(0)

    svg = re.sub(
        r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"',
        expand_viewbox,
        svg,
        count=1,
    )

    # 2. Set overflow="visible" on root <svg> (remove existing attr first)
    svg = re.sub(r'\s+overflow="[^"]*"', '', svg, count=1)
    svg = re.sub(r'(<svg\b)', r'\1 overflow="visible"', svg, count=1)

    # 3. Inject CSS to fix foreignObject text clipping.
    #    - overflow:visible  : foreignObject 外へのはみ出しを許可（安全網）
    #    - font-size:14px    : #mermaid-svg の ID セレクタ(1,0,0) を !important で上書き
    #    - line-height:1.2   : div の inline style line-height:1.5 を !important で上書き
    #      → 14px × 1.2 = 16.8px < foreignObject height="21" を確実に下回る
    FO_CSS = (
        "#mermaid-svg foreignObject{"
        "overflow:visible!important;"
        "}"
        "#mermaid-svg foreignObject>div,"
        "#mermaid-svg foreignObject>div>span,"
        "#mermaid-svg foreignObject p{"
        "font-size:14px!important;"
        "line-height:1.2!important;"
        "}"
    )
    svg = svg.replace("</svg>", f"<style>{FO_CSS}</style></svg>", 1)

    # 4. Inject background rect.
    #    themeVariables.background は mermaid.ink の SVG 出力に反映されないため、
    #    viewBox（拡張済み）全体をカバーする <rect> を SVG の先頭要素として直接挿入する。
    if background:
        vb_match = re.search(
            r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', svg
        )
        if vb_match:
            vx, vy, vw, vh = vb_match.groups()
            bg_rect = (
                f'<rect x="{vx}" y="{vy}" width="{vw}" height="{vh}"'
                f' fill="{background}"/>'
            )
            svg = re.sub(
                r'(<svg\b[^>]*>)',
                lambda m: m.group(1) + bg_rect,
                svg,
                count=1,
            )

    return svg


def wrap_tables(html: str) -> str:
    """Wrap <table> elements in a scrollable container div.

    Using display:block on <table> overrides the browser's table layout engine,
    causing the first column to be laid out at min-content width (width of the
    longest single word) rather than the natural content width.  Wrapping with
    a div and keeping the table as display:table restores correct column widths
    while still enabling horizontal scrolling for wide tables.
    """
    return re.sub(
        r'(<table\b[^>]*>.*?</table>)',
        r'<div class="table-scroll">\1</div>',
        html,
        flags=re.DOTALL,
    )


def normalize_mermaid_newlines(code: str) -> str:
    """Replace literal \\n in mermaid node labels with <br/> for correct rendering.
    mermaid.ink does not always interpret \\n as a line break; <br/> is more reliable.
    """
    return code.replace('\\n', '<br/>')


def process_mermaid_blocks(md_text: str) -> tuple:
    """
    Extract mermaid code blocks from Markdown, replace with placeholders.
    Returns modified md_text and a dict of {placeholder: svg_html}.
    """
    placeholders = {}
    counter = [0]

    def replace_mermaid(m):
        code = normalize_mermaid_newlines(m.group(1).strip())
        counter[0] += 1
        key = f"MERMAID_PLACEHOLDER_{counter[0]}_END"
        svg = fetch_mermaid_svg(code)
        # BOM・先頭空白を除いた先頭がSVG/XML宣言で始まることを厳格チェック
        svg_stripped = svg.lstrip("﻿").lstrip()
        if svg_stripped.startswith("<svg") or svg_stripped.startswith("<?xml"):
            # init ディレクティブに background が指定されている場合は注入しない
            background = None if has_background_in_init(code) else "#ffffff"
            svg = postprocess_svg(svg, background=background)
            placeholders[key] = f'<div class="mermaid-figure">{svg}</div>'
        else:
            placeholders[key] = svg
        return f"\n\n{key}\n\n"

    pattern = re.compile(r"```mermaid\s*\n(.*?)```", re.DOTALL)
    md_text = pattern.sub(replace_mermaid, md_text)
    return md_text, placeholders


def restore_placeholders(html: str, placeholders: dict) -> str:
    """Replace placeholder strings with their SVG content in the final HTML."""
    for key, value in placeholders.items():
        html = html.replace(f"<p>{key}</p>", value)
        html = html.replace(key, value)
    return html


def embed_images_in_html(html: str, base_dir: Path) -> str:
    """Find all <img src="..."> and embed local images as base64."""
    def replace_src(m):
        src = m.group(1)
        new_src = embed_image(src, base_dir)
        return f'src="{new_src}"'

    return re.sub(r'src="([^"]+)"', replace_src, html)


def get_pygments_css() -> str:
    """Generate Pygments syntax highlight CSS."""
    try:
        from pygments.formatters import HtmlFormatter
        formatter = HtmlFormatter(style="friendly")
        return formatter.get_style_defs(".highlight")
    except ImportError:
        return ""


def read_css_template(css_path: Path) -> str:
    """Read the CSS template file."""
    if css_path.exists():
        return css_path.read_text(encoding="utf-8")
    return ""


def read_js_asset(js_path: Path) -> str:
    """Read a JS asset file."""
    if js_path.exists():
        return js_path.read_text(encoding="utf-8")
    return ""


def load_js_features(js_dir: Path) -> list:
    """Load available JS features from features.json in the JS assets directory.
    Returns a list of dicts: [{"file": "...", "name": "...", "description": "..."}]
    """
    manifest_path = js_dir / "features.json"
    if not manifest_path.exists():
        return []
    with open(manifest_path, encoding="utf-8") as f:
        data = json.load(f)
    return data.get("features", [])


def combine_js_assets(js_dir: Path, selected_files: list) -> str:
    """Read and concatenate selected JS feature files in order.
    Each file is wrapped with a comment header for traceability.
    Filenames containing path separators or `..` are rejected to prevent
    traversal outside js_dir.
    Returns a single JS string safe to embed in <script> tags.
    """
    parts = []
    for filename in selected_files:
        # ファイル名に `/`・`\`・`..` が含まれる場合は拒否（パストラバーサル対策）
        if "/" in filename or "\\" in filename or filename == ".." or filename.startswith(".."):
            print(f"Warning: invalid JS feature filename rejected: {filename}", file=sys.stderr)
            continue
        js_path = js_dir / filename
        if not _is_within(js_dir, js_path):
            print(f"Warning: JS feature path escapes assets dir: {filename}", file=sys.stderr)
            continue
        content = read_js_asset(js_path)
        if content:
            parts.append(f"/* --- {filename} --- */\n{content}")
        else:
            print(f"Warning: JS feature file not found: {js_path}", file=sys.stderr)
    return "\n\n".join(parts)


def minify_css(css: str) -> str:
    """Minify CSS using rcssmin. Falls back to the original string if unavailable."""
    try:
        import rcssmin
        return rcssmin.cssmin(css)
    except ImportError:
        print("Warning: rcssmin not installed — CSS will not be minified.", file=sys.stderr)
        return css


def minify_js(js: str) -> str:
    """Minify JS using rjsmin. Falls back to the original string if unavailable."""
    try:
        import rjsmin
        return rjsmin.jsmin(js)
    except ImportError:
        print("Warning: rjsmin not installed — JS will not be minified.", file=sys.stderr)
        return js


def read_html_template(template_path: Path) -> str:
    """Read the HTML template file."""
    if template_path.exists():
        return template_path.read_text(encoding="utf-8")
    return ""


def render_html_template(template: str, **kwargs) -> str:
    """Replace {{PLACEHOLDER}} markers in template with provided values.
    Placeholders absent from the template are silently skipped —
    intentional removal by the user is preserved.
    """
    for key, value in kwargs.items():
        template = template.replace(f"{{{{{key}}}}}", value)
    return template


def strip_html_comments(html: str) -> str:
    """Remove all HTML comments (<!-- ... -->) from the rendered output.
    Template files use comments for placeholder documentation; these must not
    appear in the generated HTML delivered to end users.
    """
    return re.sub(r"<!--.*?-->", "", html, flags=re.DOTALL)


def convert_markdown_to_html(md_text: str) -> tuple:
    """Convert markdown to HTML using python-markdown with extensions."""
    import markdown
    extensions = [
        "tables",
        "fenced_code",
        "codehilite",
        "toc",
        "sane_lists",
    ]
    extension_configs = {
        "codehilite": {
            "css_class": "highlight",
            "linenums": False,
            "guess_lang": False,
        },
        "toc": {
            # H1はdoc-titleとして別途表示するため目次から除外
            "toc_depth": "2-6",
            # titleはCSSの::beforeで表示するため設定しない
        },
    }
    md = markdown.Markdown(extensions=extensions, extension_configs=extension_configs)
    body_html = md.convert(md_text)
    toc_html = getattr(md, "toc", "")
    return body_html, toc_html


def remove_first_h1(html: str) -> str:
    """Remove the first <h1>...</h1> from body HTML (shown separately as doc-title)."""
    return re.sub(r"<h1[^>]*>.*?</h1>", "", html, count=1, flags=re.DOTALL)


def extract_title_from_md(md_text: str) -> str:
    """Extract first H1 heading from markdown as document title."""
    m = re.search(r"^#\s+(.+)$", md_text, re.MULTILINE)
    if m:
        return m.group(1).strip()
    return "Document"


def build_html(
    title: str,
    toc_html: str,
    body_html: str,
    css: str,
    pygments_css: str,
    combined_js: str,
    html_template: str,
) -> str:
    """Assemble the final self-contained HTML document using the external template."""
    toc_section = ""
    if toc_html and toc_html.strip():
        toc_section = f'<aside id="toc-sidebar">{toc_html}</aside>'

    js_block = f"<script>{combined_js}</script>" if combined_js.strip() else ""

    rendered = render_html_template(
        html_template,
        TITLE=title,
        CSS=css,
        PYGMENTS_CSS=pygments_css,
        TOC_SIDEBAR=toc_section,
        BODY_HTML=body_html,
        JS_BLOCK=js_block,
    )
    return strip_html_comments(rendered)


def main():
    parser = argparse.ArgumentParser(description="Convert Markdown to self-contained HTML")
    parser.add_argument("input", help="Input .md file path")
    parser.add_argument("output", nargs="?", help="Output .html file path")
    parser.add_argument("--title", help="Document title (default: extracted from first H1)")
    parser.add_argument(
        "--css-template",
        help=(
            "Path to CSS template file. Default resolution order: "
            "skill-level assets/css/template.css (override), then plugin-level "
            "assets/css/template.css (shared)."
        ),
    )
    parser.add_argument(
        "--js-features",
        help="Comma-separated JS feature filenames to include (default: all features in features.json). "
             "Example: --js-features lightbox.js,other.js",
    )
    parser.add_argument(
        "--html-template",
        help=(
            "Path to HTML skeleton template file. Default resolution order: "
            "skill-level assets/html/template.html (override), then plugin-level "
            "assets/html/template.html (shared)."
        ),
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path.with_suffix(".html")

    # Path(__file__) = scripts/convert/convert.py
    script_dir = Path(__file__).resolve().parent
    skill_root = script_dir.parent.parent            # skills/convert-html/
    plugin_root = skill_root.parent.parent           # plugins/convert-doc/

    def _resolve_asset(relative_path: str) -> Path:
        """Return the first existing path for ``relative_path``.

        Search order: skill-level override, then plugin-level shared asset.
        Falls back to the plugin-level path even if it does not exist, so the
        downstream error message includes the shared location.
        """
        for base in (skill_root, plugin_root):
            candidate = base / relative_path
            if candidate.exists():
                return candidate
        return plugin_root / relative_path

    if args.css_template:
        css_template_path = Path(args.css_template)
    else:
        css_template_path = _resolve_asset("assets/css/template.css")

    if args.html_template:
        html_template_path = Path(args.html_template)
    else:
        html_template_path = _resolve_asset("assets/html/template.html")

    # 元のテキストをタイトル抽出用に保持
    original_md = input_path.read_text(encoding="utf-8")
    md_text = original_md

    # Step 0: JSフィーチャー確認（目次有効/無効の判定）
    # toc-toggle.js が選択フィーチャーに含まれる場合のみ目次を出力する
    js_dir = skill_root / "assets" / "js"
    features = load_js_features(js_dir)
    if args.js_features is not None:
        selected_js = [f.strip() for f in args.js_features.split(",") if f.strip()]
    else:
        selected_js = [f["file"] for f in features]
    toc_enabled = "toc-toggle.js" in selected_js

    # Step 1: 前処理（打ち消し線・GFM タスクリスト）
    md_text = preprocess_strikethrough(md_text)
    md_text = preprocess_task_lists(md_text)

    # Step 2: 手書き目次セクション（## 目次）を削除（目次機能が有効な場合のみ）
    if toc_enabled:
        md_text = remove_inline_toc(md_text)

    # Step 3: Mermaidブロックを先に処理（APIコール）
    md_text_processed, mermaid_map = process_mermaid_blocks(md_text)

    # Step 4: Markdown → HTML変換
    body_html, toc_html = convert_markdown_to_html(md_text_processed)

    # Step 5: MermaidのSVGを復元
    body_html = restore_placeholders(body_html, mermaid_map)

    # Step 6: ローカル画像をbase64埋め込み
    body_html = embed_images_in_html(body_html, input_path.parent)

    # Step 6b: テーブルを横スクロールラッパーで囲む（列幅の自然計算を維持）
    body_html = wrap_tables(body_html)

    # Step 7: H1はdoc-titleで表示するためbodyから除去
    body_html = remove_first_h1(body_html)

    # Step 8: タイトル決定（前処理前の元テキストから取得）
    title = args.title or extract_title_from_md(original_md)

    # Step 9: 目次処理（目次機能が無効な場合は出力しない。リンクは保持して該当箇所へジャンプ可能にする）
    if not toc_enabled:
        toc_html = ""

    # Step 10: CSS読み込み
    css = read_css_template(css_template_path)
    if not css:
        print(f"Warning: CSS template not found at {css_template_path}", file=sys.stderr)

    # Step 11: Pygments CSS
    pygments_css = get_pygments_css()

    # Step 11a: CSS minify（テンプレートCSS + Pygments CSS）
    css = minify_css(css)
    pygments_css = minify_css(pygments_css)

    # Step 12: JSフィーチャー結合（フィーチャー選択は Step 0 で確定済み）
    combined_js = combine_js_assets(js_dir, selected_js)

    # Step 12a: JS minify
    combined_js = minify_js(combined_js)

    # Step 13: HTMLテンプレート読み込み
    html_template = read_html_template(html_template_path)
    if not html_template:
        print(f"Error: HTML template not found at {html_template_path}", file=sys.stderr)
        sys.exit(1)

    # Step 14: HTML生成・出力
    html = build_html(title, toc_html, body_html, css, pygments_css, combined_js, html_template)
    output_path.write_text(html, encoding="utf-8")
    print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()
