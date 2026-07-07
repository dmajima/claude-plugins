#!/usr/bin/env python3
"""validate_html.py - Validate a paired design HTML template for convert-html.

A design may ship its own HTML template (same basename as the design CSS).
The template is only allowed to change structure in ways that do NOT break
the JS features, so this script enforces:

- all conversion placeholders survive ({{TITLE}}, {{CSS}}, {{PYGMENTS_CSS}},
  {{TOC_SIDEBAR}}, {{BODY_HTML}}, {{JS_BLOCK}}) - a dropped placeholder
  silently disables that feature for the whole design
- the skeleton DOM the JS and CSS contracts rely on stays present
  (#wrap, #main-content, .doc-title, .article-body)
- {{CSS}} is embedded inside a <style> block

Usage:
  python validate_html.py <design.html>

Exit codes: 0 = PASS, 1 = FAIL, 2 = usage error.
"""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

REQUIRED_PLACEHOLDERS = [
    "{{TITLE}}", "{{CSS}}", "{{PYGMENTS_CSS}}",
    "{{TOC_SIDEBAR}}", "{{BODY_HTML}}", "{{JS_BLOCK}}",
]

# (check id, regex, message) — id values must match exactly (closing quote;
# both quote styles accepted)
REQUIRED_DOM_IDS = [
    ("skeleton", r'id\s*=\s*(["\'])wrap\1', 'element with id="wrap" exists'),
    ("skeleton", r'id\s*=\s*(["\'])main-content\1', 'element with id="main-content" exists'),
]

# class attributes are token lists; "doc-title-badge" must NOT satisfy
# "doc-title", so values are split on whitespace and compared exactly.
REQUIRED_DOM_CLASSES = [
    ("skeleton", "doc-title", 'element with class "doc-title" exists'),
    ("skeleton", "article-body", 'element with class "article-body" exists'),
]


def has_class_token(html: str, token: str) -> bool:
    for m in re.finditer(r'class\s*=\s*(["\'])(.*?)\1', html, flags=re.IGNORECASE):
        if token in m.group(2).split():
            return True
    return False

RECOMMENDED = [
    ("meta", r'<meta\s+charset\s*=\s*"?UTF-8"?', '<meta charset="UTF-8"> present'),
    ("meta", r'<meta\s+name\s*=\s*"viewport"', "viewport meta present"),
    ("lang", r"<html[^>]*\slang\s*=", "<html lang=...> present"),
]


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_html.py <design.html>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Error: file not found: {path}", file=sys.stderr)
        return 2
    try:
        html = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        print(f"Error: cannot read {path} as UTF-8: {e}", file=sys.stderr)
        return 2

    # Ignore comments so documentation blocks don't satisfy checks.
    stripped = re.sub(r"<!--.*?-->", "", html, flags=re.DOTALL)
    failed = warned = 0

    for ph in REQUIRED_PLACEHOLDERS:
        if ph in stripped:
            print(f"[PASS] placeholder: {ph} survives")
        else:
            print(f"[FAIL] placeholder: {ph} is missing "
                  "(that conversion feature would be silently disabled)")
            failed += 1

    for check_id, pattern, message in REQUIRED_DOM_IDS:
        if re.search(pattern, stripped, flags=re.IGNORECASE):
            print(f"[PASS] {check_id}: {message}")
        else:
            print(f"[FAIL] {check_id}: {message}")
            failed += 1

    for check_id, token, message in REQUIRED_DOM_CLASSES:
        if has_class_token(stripped, token):
            print(f"[PASS] {check_id}: {message}")
        else:
            print(f"[FAIL] {check_id}: {message}")
            failed += 1

    style_blocks = re.findall(r"<style[^>]*>(.*?)</style>", stripped,
                              flags=re.DOTALL | re.IGNORECASE)
    if any("{{CSS}}" in b for b in style_blocks):
        print("[PASS] style: {{CSS}} is inside a <style> block")
    else:
        print("[FAIL] style: {{CSS}} must be embedded inside a <style> block")
        failed += 1

    # {{TOC_SIDEBAR}} must appear before {{JS_BLOCK}} so toc-toggle.js can
    # find #toc-sidebar when it initializes.
    toc_pos = stripped.find("{{TOC_SIDEBAR}}")
    js_pos = stripped.find("{{JS_BLOCK}}")
    if toc_pos != -1 and js_pos != -1:
        if toc_pos < js_pos:
            print("[PASS] order: {{TOC_SIDEBAR}} appears before {{JS_BLOCK}}")
        else:
            print("[FAIL] order: {{TOC_SIDEBAR}} must appear before {{JS_BLOCK}} "
                  "(toc-toggle.js looks up #toc-sidebar at load)")
            failed += 1

    for check_id, pattern, message in RECOMMENDED:
        if re.search(pattern, stripped, flags=re.IGNORECASE):
            print(f"[PASS] {check_id}: {message}")
        else:
            print(f"[WARN] {check_id}: {message}")
            warned += 1

    print()
    if failed:
        print(f"RESULT: FAIL ({failed} required, {warned} warnings)")
        return 1
    print(f"RESULT: PASS ({warned} warnings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
