#!/usr/bin/env python3
"""validate_theme.py - Validate a PPTX theme JSON for convert-pptx.

Delegates to convert_pptx.load_theme() (the same code path the converter
uses) so validation can never drift from actual behavior. On success it
prints which fields the theme overrides.

Usage:
  python validate_theme.py <theme.json>

Exit codes: 0 = PASS, 1 = FAIL (schema/color/value error), 2 = usage error.
"""
import sys
from dataclasses import fields
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

# convert_pptx.py lives in the sibling script directory; resolve it relative
# to this file so the pair keeps working wherever the plugin is installed.
_CONVERT_PPTX_DIR = Path(__file__).resolve().parent.parent / "convert-pptx"
sys.path.insert(0, str(_CONVERT_PPTX_DIR))

try:
    from convert_pptx import Theme, load_theme  # noqa: E402
except (ImportError, AssertionError) as e:
    # AssertionError: convert_pptx's import-time mapping-table self-check
    print(f"Error: cannot import convert_pptx from {_CONVERT_PPTX_DIR}: {e}",
          file=sys.stderr)
    sys.exit(2)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_theme.py <theme.json>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Error: file not found: {path}", file=sys.stderr)
        return 2
    try:
        path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        # Unreadable input is a usage error (exit 2), matching the sibling
        # validators (validate_css.py / validate_html.py).
        print(f"Error: cannot read {path} as UTF-8: {e}", file=sys.stderr)
        return 2

    try:
        theme = load_theme(path)
    except ValueError as e:
        print(f"[FAIL] {e}")
        print()
        print("RESULT: FAIL")
        return 1

    default = Theme()
    overridden = []
    for f in fields(Theme):
        if getattr(theme, f.name) != getattr(default, f.name):
            overridden.append(f.name)

    print(f"[PASS] {path.name}: valid theme JSON")
    if overridden:
        print(f"[INFO] overrides {len(overridden)} field(s): {', '.join(overridden)}")
    else:
        print("[WARN] theme overrides nothing (output is identical to the default design)")
    print()
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
