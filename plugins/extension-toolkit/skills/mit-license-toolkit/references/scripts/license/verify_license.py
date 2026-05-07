#!/usr/bin/env python3
"""Verify a plugin has a MIT LICENSE matching the canonical template.

Usage:
    python verify_license.py <plugin-dir>

Exit codes:
- 0: pass
- 1: argument error
- 2: LICENSE missing
- 3: LICENSE body does not match MIT template (excluding copyright line)
- 4: copyright line empty or contains placeholder
- 5: plugin.json.license != "MIT"
- 6: MIT template file missing (environment / install issue)
- 7: plugin.json missing (cannot validate license field)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

COPYRIGHT_RE = re.compile(r"^Copyright \(c\) (\S+) (.+)$")


def resolve_template_path() -> Path:
    skill_dir = os.environ.get("CLAUDE_SKILL_DIR")
    if skill_dir:
        candidate = Path(skill_dir) / "references" / "template" / "LICENSE"
        if candidate.is_file():
            return candidate
    here = Path(__file__).resolve()
    candidate = here.parent.parent.parent / "template" / "LICENSE"
    if candidate.is_file():
        return candidate
    print(f"[ERROR] LICENSE template not found near {here}", file=sys.stderr)
    sys.exit(6)


def normalize(body: str) -> list[str]:
    """Strip the copyright line so the rest can be compared against the template."""
    lines = body.splitlines()
    return [line for line in lines if not line.startswith("Copyright (c)")]


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify MIT LICENSE for a plugin")
    parser.add_argument("plugin_dir", help="Path to plugin directory")
    args = parser.parse_args()

    plugin_dir = Path(args.plugin_dir).resolve()
    license_path = plugin_dir / "LICENSE"
    plugin_json_path = plugin_dir / ".claude-plugin" / "plugin.json"

    if not license_path.is_file():
        print(f"[FAIL] LICENSE missing: {license_path}", file=sys.stderr)
        return 2

    template_path = resolve_template_path()
    template_text = template_path.read_text(encoding="utf-8")
    actual_text = license_path.read_text(encoding="utf-8")

    if normalize(template_text) != normalize(actual_text):
        print("[FAIL] LICENSE body differs from canonical MIT template", file=sys.stderr)
        return 3

    copyright_lines = [line for line in actual_text.splitlines() if line.startswith("Copyright (c)")]
    if not copyright_lines:
        print("[FAIL] Copyright line missing", file=sys.stderr)
        return 4
    match = COPYRIGHT_RE.match(copyright_lines[0])
    if not match:
        print(f"[FAIL] Copyright line malformed: {copyright_lines[0]}", file=sys.stderr)
        return 4
    year, holder = match.group(1).strip(), match.group(2).strip()
    if not year or not holder or "{" in year or "{" in holder:
        print(f"[FAIL] Year or holder empty/placeholder: '{year}' '{holder}'", file=sys.stderr)
        return 4

    if not plugin_json_path.is_file():
        print(f"[FAIL] plugin.json missing: {plugin_json_path}", file=sys.stderr)
        return 7
    data = json.loads(plugin_json_path.read_text(encoding="utf-8"))
    if data.get("license") != "MIT":
        print(f"[FAIL] plugin.json.license is {data.get('license')!r}, expected 'MIT'", file=sys.stderr)
        return 5
    print(f"[PASS] {plugin_dir} has valid MIT LICENSE (year={year}, holder={holder})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
