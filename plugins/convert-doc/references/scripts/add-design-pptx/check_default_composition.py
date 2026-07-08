#!/usr/bin/env python3
"""check_default_composition.py - Verify the default-composition reference.

The SSOT for the default composition is convert_pptx.build_default_composition().
theme-schema.md (add-design-pptx skill) carries a human-readable reference copy
between `<!-- default-composition-16x9:begin/end -->` markers; this script
compares that copy against the code so the two can never silently drift.

The reference is materialized with the default Theme at 16:9 (13.333 x 7.5 in).
Floats are compared with a tolerance because the code derives some values
arithmetically (e.g. content_top = title_band_height + 0.2) while the document
lists the rounded human-facing number.

Usage:
  python check_default_composition.py

Exit codes: 0 = PASS (in sync), 1 = FAIL (drift detected), 2 = environment error.
"""
import json
import math
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

# Resolve everything relative to this file so the trio (this script,
# convert_pptx.py, theme-schema.md) keeps working wherever the plugin is
# installed: add-design-pptx/ -> scripts/ -> references/ -> plugin root.
_PLUGIN_ROOT = Path(__file__).resolve().parents[3]
_CONVERT_PPTX_DIR = _PLUGIN_ROOT / "references" / "scripts" / "convert-pptx"
_SCHEMA_MD = _PLUGIN_ROOT / "skills" / "add-design-pptx" / "references" / "theme-schema.md"

sys.path.insert(0, str(_CONVERT_PPTX_DIR))

try:
    from convert_pptx import Theme, _composition_to_dict, build_default_composition  # noqa: E402
except (ImportError, AssertionError) as e:
    print(f"Error: cannot import convert_pptx from {_CONVERT_PPTX_DIR}: {e}", file=sys.stderr)
    sys.exit(2)

_MARKER_RE = re.compile(
    r"<!--\s*default-composition-16x9:begin\s*-->\s*```json\s*(.*?)\s*```\s*"
    r"<!--\s*default-composition-16x9:end\s*-->",
    re.DOTALL,
)


def _diff(expected, actual, path: str, problems: list) -> None:
    """Recursively compare the documented reference vs the code output."""
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key in sorted(set(expected) | set(actual)):
            here = f"{path}.{key}" if path else key
            if key not in expected:
                problems.append(f"{here}: only in code output (missing from document)")
            elif key not in actual:
                problems.append(f"{here}: only in document (missing from code output)")
            else:
                _diff(expected[key], actual[key], here, problems)
        return
    if isinstance(expected, list) and isinstance(actual, list):
        if len(expected) != len(actual):
            problems.append(f"{path}: length {len(expected)} (document) != {len(actual)} (code)")
            return
        for i in range(len(expected)):
            _diff(expected[i], actual[i], f"{path}[{i}]", problems)
        return
    if isinstance(expected, bool) or isinstance(actual, bool):
        # bool before number: True == 1 would otherwise slip through.
        if expected is not actual:
            problems.append(f"{path}: {expected!r} (document) != {actual!r} (code)")
        return
    if isinstance(expected, (int, float)) and isinstance(actual, (int, float)):
        if not math.isclose(float(expected), float(actual), rel_tol=1e-9, abs_tol=1e-9):
            problems.append(f"{path}: {expected!r} (document) != {actual!r} (code)")
        return
    if expected != actual:
        problems.append(f"{path}: {expected!r} (document) != {actual!r} (code)")


def main() -> int:
    if not _SCHEMA_MD.exists():
        print(f"Error: theme-schema.md not found: {_SCHEMA_MD}", file=sys.stderr)
        return 2
    text = _SCHEMA_MD.read_text(encoding="utf-8")
    m = _MARKER_RE.search(text)
    if not m:
        print(
            "[FAIL] default-composition-16x9 markers not found in theme-schema.md "
            "(the reference block was removed or the markers were renamed)"
        )
        print()
        print("RESULT: FAIL")
        return 1
    try:
        documented = json.loads(m.group(1))
    except json.JSONDecodeError as e:
        print(f"[FAIL] reference block in theme-schema.md is not valid JSON: {e}")
        print()
        print("RESULT: FAIL")
        return 1

    actual = _composition_to_dict(build_default_composition(Theme(), 13.333, 7.5))

    problems: list = []
    _diff(documented, actual, "", problems)
    if problems:
        print("[FAIL] theme-schema.md reference has drifted from build_default_composition():")
        for p in problems:
            print(f"  - {p}")
        print()
        print("RESULT: FAIL")
        return 1

    print("[PASS] theme-schema.md default-composition reference matches build_default_composition()")
    print()
    print("RESULT: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
