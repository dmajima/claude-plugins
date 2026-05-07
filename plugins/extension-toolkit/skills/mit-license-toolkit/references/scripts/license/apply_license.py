#!/usr/bin/env python3
"""Apply MIT LICENSE to a plugin and update plugin.json's license field.

Usage:
    python apply_license.py <plugin-dir> --year <year> --holder <holder> [--author <author>]

Behavior (ADR-029 / license-policy.md):
- Reads MIT template from $CLAUDE_SKILL_DIR/references/template/LICENSE
- Substitutes {year} / {copyright_holder} placeholders
- Writes <plugin-dir>/LICENSE (UTF-8, LF)
- Sets plugin.json's "license" field to "MIT" (preserves existing key order via json.dump)
- If author is provided AND plugin.json has no author.name, sets it (caller decides whether to do so via UI confirmation; this script only writes if --author is given)

Exit codes:
- 0: success
- 1: argument error
- 2: target plugin path invalid (no plugin.json)
- 4: placeholder remains after substitution (write failure)
- 6: MIT template file missing (environment / install issue)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


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


def render_license(template_text: str, year: str, holder: str) -> str:
    rendered = template_text.replace("{year}", year).replace("{copyright_holder}", holder)
    if "{year}" in rendered or "{copyright_holder}" in rendered:
        print("[ERROR] Placeholder remains after substitution", file=sys.stderr)
        sys.exit(4)
    return rendered


def write_license_file(plugin_dir: Path, content: str) -> Path:
    target = plugin_dir / "LICENSE"
    with target.open("w", encoding="utf-8", newline="\n") as f:
        f.write(content)
    return target


def update_plugin_json(plugin_dir: Path, author: "str | None") -> Path:
    plugin_json = plugin_dir / ".claude-plugin" / "plugin.json"
    if not plugin_json.is_file():
        print(f"[ERROR] plugin.json not found: {plugin_json}", file=sys.stderr)
        sys.exit(2)
    raw = plugin_json.read_text(encoding="utf-8")
    data = json.loads(raw)
    data["license"] = "MIT"
    if author:
        existing_author = data.get("author")
        if not isinstance(existing_author, dict) or not existing_author.get("name"):
            data["author"] = {"name": author}
    serialized = json.dumps(data, indent=2, ensure_ascii=False)
    with plugin_json.open("w", encoding="utf-8", newline="\n") as f:
        f.write(serialized + "\n")
    return plugin_json


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply MIT LICENSE to a plugin")
    parser.add_argument("plugin_dir", help="Path to plugin directory (contains .claude-plugin/plugin.json)")
    parser.add_argument("--year", required=True, help="Copyright year (e.g. 2026)")
    parser.add_argument("--holder", required=True, help="Copyright holder (person or organization)")
    parser.add_argument("--author", default=None, help="Plugin author name (sets plugin.json.author.name only if absent)")
    args = parser.parse_args()

    plugin_dir = Path(args.plugin_dir).resolve()
    if not (plugin_dir / ".claude-plugin" / "plugin.json").is_file():
        print(f"[ERROR] Not a plugin directory: {plugin_dir}", file=sys.stderr)
        return 2

    template_path = resolve_template_path()
    template_text = template_path.read_text(encoding="utf-8")
    rendered = render_license(template_text, args.year, args.holder)

    license_path = write_license_file(plugin_dir, rendered)
    plugin_json_path = update_plugin_json(plugin_dir, args.author)

    print(f"[OK] Wrote {license_path}")
    print(f"[OK] Updated {plugin_json_path} (license=MIT)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
