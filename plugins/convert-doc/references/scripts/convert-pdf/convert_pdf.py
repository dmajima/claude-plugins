#!/usr/bin/env python3
"""
convert_pdf.py - Markdown to PDF converter (via convert-html + Playwright/Chromium)

Usage:
  python convert_pdf.py <input.md> [output.pdf]
    [--title TITLE]
    [--format A4]
    [--landscape]
    [--margin 20mm]
    [--no-background]

Dependencies: playwright (+ chromium), markdown, Pygments, rcssmin, rjsmin, Pillow
"""

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional


def locate_convert_html_script() -> Path:
    """Return the path to the convert-html business script under the plugin's references/scripts/.

    Resolution order (ADR-024 / ADR-025 準拠):
      1. ``CONVERT_HTML_SCRIPT`` env var (explicit override)
      2. ``CLAUDE_PLUGIN_ROOT`` env var (set by Claude Code at runtime) +
         ``references/scripts/convert-html/convert.py``
      3. Same-plugin sibling fallback derived from ``__file__``
    """
    explicit = os.environ.get("CONVERT_HTML_SCRIPT")
    if explicit:
        p = Path(explicit)
        if p.exists():
            return p

    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if plugin_root:
        candidate = Path(plugin_root) / "references" / "scripts" / "convert-html" / "convert.py"
        if candidate.exists():
            return candidate

    # Fallback: same-plugin sibling derived from this file's location.
    # references/scripts/convert-pdf/  -> references/scripts/  -> convert-html/convert.py
    this_file = Path(__file__).resolve()
    sibling = this_file.parent.parent / "convert-html" / "convert.py"
    if sibling.exists():
        return sibling

    print(
        "Error: convert-html script not found via $CONVERT_HTML_SCRIPT, "
        "$CLAUDE_PLUGIN_ROOT, or sibling fallback.",
        file=sys.stderr,
    )
    sys.exit(1)


def parse_margin(value: str) -> dict:
    """Parse --margin value into Playwright's margin dict.

    Accepted forms:
      "20mm"                         -> all four sides the same
      "20mm 15mm"                    -> top/bottom 20mm, right/left 15mm
      "20mm 15mm 25mm 15mm"          -> top right bottom left
    """
    parts = value.split()
    if len(parts) == 1:
        t = r = b = l = parts[0]
    elif len(parts) == 2:
        t = b = parts[0]
        r = l = parts[1]
    elif len(parts) == 4:
        t, r, b, l = parts
    else:
        raise ValueError(
            "--margin must be 1, 2, or 4 whitespace-separated values (e.g. '20mm' or '20mm 15mm 25mm 15mm')"
        )
    return {"top": t, "right": r, "bottom": b, "left": l}


def generate_html(input_md: Path, title: Optional[str], workspace_tmp: Path) -> Path:
    """Generate a self-contained HTML from Markdown using the sibling convert-html skill.
    The HTML is written into a temp directory and its path is returned.
    """
    convert_html = locate_convert_html_script()
    html_path = workspace_tmp / (input_md.stem + ".html")
    cmd = [sys.executable, str(convert_html), str(input_md), str(html_path)]
    if title:
        cmd.extend(["--title", title])
    print(f"[convert-pdf] generating HTML via convert-html: {html_path}")
    subprocess.run(cmd, check=True)
    if not html_path.exists():
        print(f"Error: convert-html did not produce {html_path}", file=sys.stderr)
        sys.exit(1)
    return html_path


def render_pdf(
    html_path: Path,
    output_pdf: Path,
    *,
    paper_format: str,
    landscape: bool,
    margin: dict,
    print_background: bool,
) -> None:
    """Open the HTML in Chromium (Playwright) and save it as PDF."""
    from playwright.sync_api import sync_playwright

    url = html_path.resolve().as_uri()  # file:///... cross-platform

    print(f"[convert-pdf] launching chromium")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        try:
            context = browser.new_context()
            page = context.new_page()
            page.goto(url, wait_until="networkidle")
            # Ensure custom fonts and inline SVG are fully laid out before snapshot
            page.wait_for_timeout(300)
            output_pdf.parent.mkdir(parents=True, exist_ok=True)
            page.pdf(
                path=str(output_pdf),
                format=paper_format,
                landscape=landscape,
                margin=margin,
                print_background=print_background,
                prefer_css_page_size=False,
            )
        finally:
            browser.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert Markdown to PDF (via convert-html + Chromium)"
    )
    parser.add_argument("input", help="Input .md file path")
    parser.add_argument("output", nargs="?", help="Output .pdf file path")
    parser.add_argument("--title", help="Document title (default: extracted from first H1)")
    parser.add_argument("--format", default="A4", help="Paper format (A4, A3, Letter, etc.)")
    parser.add_argument("--landscape", action="store_true", help="Landscape orientation")
    parser.add_argument(
        "--margin",
        default="20mm",
        help="Margin ('20mm', '20mm 15mm', or '20mm 15mm 25mm 15mm')",
    )
    parser.add_argument(
        "--no-background",
        action="store_true",
        help="Do not print background colors/images",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path = Path(args.output) if args.output else input_path.with_suffix(".pdf")
    output_path = output_path.resolve()

    margin = parse_margin(args.margin)

    # Work in a temp directory for the intermediate HTML so we do not pollute the user's tree.
    with tempfile.TemporaryDirectory(prefix="convert-pdf-") as tmp_str:
        tmp_dir = Path(tmp_str)
        html_path = generate_html(input_path, args.title, tmp_dir)
        render_pdf(
            html_path,
            output_path,
            paper_format=args.format,
            landscape=args.landscape,
            margin=margin,
            print_background=not args.no_background,
        )

    print(f"Generated: {output_path}")


if __name__ == "__main__":
    main()
