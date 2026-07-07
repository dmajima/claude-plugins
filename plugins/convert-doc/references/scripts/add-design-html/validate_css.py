#!/usr/bin/env python3
"""validate_css.py - Validate a design CSS against the convert-html contract.

A new design CSS must keep every selector contract that the shared HTML
template (assets/html/template.html), the converter (convert.py) and the
bundled JS features (toc-toggle.js / lightbox.js) rely on. This script
checks those contracts mechanically so that swapping CSS never breaks the
JS behavior.

Usage:
  python validate_css.py <design.css>

Exit codes: 0 = PASS (warnings allowed), 1 = FAIL (required check failed),
2 = usage error (missing/unreadable/non-UTF-8 file).
"""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

# --- Required: skeleton selectors emitted by template.html -----------------
SKELETON_SELECTORS = ["#wrap", "#main-content", ".doc-title", ".article-body"]

# --- Required: DOM ids/classes created or toggled by toc-toggle.js ---------
TOC_JS_CONTRACT = [
    "#toc-sidebar",
    "#toc-toggle-btn",
    "#toc-mobile-header",
    "#toc-hamburger-btn",
    "#toc-mobile-overlay",
    ".toc-collapsed",
    ".toc-mobile-open",
]

# --- Required: DOM ids created by lightbox.js -------------------------------
LIGHTBOX_JS_CONTRACT = ["#lb-overlay", "#lb-box", "#lb-close", "#lb-hint"]

# toc-toggle.js hardcodes MOBILE_BREAKPOINT = 1024; the CSS must switch
# desktop/mobile layout at the same boundary.
JS_MOBILE_BREAKPOINT_PX = 1024

# --- Recommended: content selectors produced by Markdown conversion --------
CONTENT_SELECTORS = [
    "h1", "h2", "h3", "h4", "h5", "h6", "p", "a", "img",
    "ul", "ol", "li", "blockquote", "code", "pre", "hr",
    "table", "th", "td", "kbd", "dl", "dt", "dd",
]

# --- Recommended: classes convert.py generates with fixed names ------------
# NOTE: .footnote is intentionally NOT listed: template.css styles it but the
# current convert.py does not enable the markdown `footnotes` extension, so
# it is a reserved style, not a generated-class contract.
GENERATED_CLASSES = [
    ".table-scroll", ".highlight", ".mermaid-figure", ".mermaid-error",
    ".task-list-item",
]


def strip_comments(css: str) -> str:
    return re.sub(r"/\*.*?\*/", "", css, flags=re.DOTALL)


_AT_RULE_RE = re.compile(r"@[A-Za-z-]+[^{;]*")


def strip_at_blocks(css: str) -> str:
    """Remove @media/@supports/@keyframes/... blocks (brace-balanced).

    The result contains only top-level rules, so "default state" checks
    (e.g. #lb-overlay { display: none }) cannot be satisfied by declarations
    nested inside a conditional at-rule.
    """
    out = []
    i, n = 0, len(css)
    while i < n:
        if css[i] == "@":
            m = _AT_RULE_RE.match(css, i)  # pos= avoids O(n^2) slicing
            if m:
                j = m.end()
                if j < n and css[j] == "{":
                    depth = 1
                    j += 1
                    while j < n and depth:
                        if css[j] == "{":
                            depth += 1
                        elif css[j] == "}":
                            depth -= 1
                        j += 1
                    i = j
                    continue
                if j < n and css[j] == ";":  # @import etc.
                    i = j + 1
                    continue
        out.append(css[i])
        i += 1
    return "".join(out)


def collect_selector_text(css: str) -> str:
    """Concatenate everything that appears in selector position (before '{')."""
    parts = []
    for m in re.finditer(r"(?:^|[}{;])\s*([^{}@;]+)\{", css):
        parts.append(m.group(1))
    return "\n".join(parts)


def selector_defined(selector_text: str, sel: str) -> bool:
    """True if `sel` appears as a complete simple-selector token.

    Boundary-checked so that e.g. '#wrap' does NOT match '#wrapper' and
    '.doc-title' does NOT match '.doc-title-badge'.
    """
    return bool(re.search(re.escape(sel) + r"(?![\w-])", selector_text))


def top_level_rule_bodies_for(css_top_level: str, sel: str) -> list:
    """Declaration bodies of top-level rules whose selector list contains `sel`
    as a complete token. `css_top_level` must be pre-stripped of at-blocks."""
    bodies = []
    token = re.escape(sel) + r"(?![\w-])"
    for m in re.finditer(r"([^{}]+)\{([^{}]*)\}", css_top_level):
        if re.search(token, m.group(1)):
            bodies.append(m.group(2))
    return bodies


class Report:
    def __init__(self):
        self.failed = 0
        self.warned = 0
        self.passed = 0

    def check(self, ok: bool, required: bool, check_id: str, message: str):
        if ok:
            self.passed += 1
            print(f"[PASS] {check_id}: {message}")
        elif required:
            self.failed += 1
            print(f"[FAIL] {check_id}: {message}")
        else:
            self.warned += 1
            print(f"[WARN] {check_id}: {message}")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_css.py <design.css>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Error: file not found: {path}", file=sys.stderr)
        return 2
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        print(f"Error: cannot read {path} as UTF-8: {e}", file=sys.stderr)
        return 2

    css = strip_comments(raw)
    rep = Report()

    # Unbalanced braces make the at-block stripper consume the rest of the file,
    # which would surface as a wall of misleading selector FAILs. Point at the
    # real cause up front (kept as a warning: a brace inside a string literal
    # could legitimately unbalance the raw count).
    rep.check(css.count("{") == css.count("}"), False, "syntax",
              f"curly braces are balanced ({css.count('{')} open / {css.count('}')} close) — "
              "an unclosed block hides every rule after it from this validator")

    css_top = strip_at_blocks(css)
    selector_text = collect_selector_text(css)

    for sel in SKELETON_SELECTORS:
        rep.check(selector_defined(selector_text, sel), True, "skeleton",
                  f"{sel} (template.html skeleton) is styled")

    for sel in TOC_JS_CONTRACT:
        rep.check(selector_defined(selector_text, sel), True, "toc-js",
                  f"{sel} (toc-toggle.js contract) is styled")
    for sel in LIGHTBOX_JS_CONTRACT:
        rep.check(selector_defined(selector_text, sel), True, "lightbox-js",
                  f"{sel} (lightbox.js contract) is styled")

    # lightbox overlay must default to hidden AT TOP LEVEL; JS only flips
    # inline display, and a display:none buried in an @media block does not
    # hide the overlay on load.
    lb_bodies = top_level_rule_bodies_for(css_top, "#lb-overlay")
    lb_hidden = any(re.search(r"display\s*:\s*none", b, re.IGNORECASE) for b in lb_bodies)
    rep.check(lb_hidden, True, "lightbox-js",
              "#lb-overlay has top-level 'display: none' by default "
              "(otherwise the overlay covers the page on load)")

    # mobile header must default to hidden on desktop (top level).
    mh_bodies = top_level_rule_bodies_for(css_top, "#toc-mobile-header")
    mh_hidden = any(re.search(r"display\s*:\s*none", b, re.IGNORECASE) for b in mh_bodies)
    rep.check(mh_hidden, True, "toc-js",
              "#toc-mobile-header has top-level 'display: none' by default "
              "(otherwise the mobile header shows on desktop)")

    # active-state class for the mobile overlay.
    rep.check(selector_defined(selector_text, ".active"), True, "toc-js",
              ".active (mobile overlay open state) is styled")

    # breakpoint must match toc-toggle.js MOBILE_BREAKPOINT.
    bp = re.search(r"@media[^{]*max-width\s*:\s*(\d+)px", css)
    bp_ok = bool(re.search(
        rf"@media[^{{]*max-width\s*:\s*{JS_MOBILE_BREAKPOINT_PX}px", css))
    detail = f"found {bp.group(1)}px" if bp else "no px max-width media query found"
    rep.check(bp_ok, True, "breakpoint",
              f"@media (max-width: {JS_MOBILE_BREAKPOINT_PX}px) exists to match "
              f"toc-toggle.js MOBILE_BREAKPOINT ({detail})")

    for sel in CONTENT_SELECTORS:
        found = bool(re.search(rf"(?<![\w.#-]){re.escape(sel)}(?![\w-])", selector_text))
        rep.check(found, False, "content", f"element '{sel}' is styled")
    for sel in GENERATED_CLASSES:
        rep.check(selector_defined(selector_text, sel), False, "generated",
                  f"{sel} (convert.py generated class) is styled")

    has_print = bool(re.search(r"@media[^{]*\bprint\b", css))
    rep.check(has_print, False, "print",
              "@media print block exists (PDF output quality)")
    if has_print:
        rep.check("print-color-adjust" in css, False, "print",
                  "print-color-adjust present (keeps backgrounds in PDF)")

    print()
    if rep.failed:
        print(f"RESULT: FAIL ({rep.failed} required, {rep.warned} warnings, {rep.passed} passed)")
        return 1
    print(f"RESULT: PASS ({rep.warned} warnings, {rep.passed} passed)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
