"""Parse skill evals into a unified schema.

Supports two formats described in design v2 section 3.5:
  - JSON   : <skill_dir>/evals/evals.json with top-level "evals" array.
  - case_md: <skill_dir>/evals/case-XX_*.md with embedded prompt patterns.

Returned schema (per case):
  {
    "id": str,
    "prompt": str,
    "expectations": list[str],
    "kind": "json" | "case_md",
  }
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

# Patterns used to harvest prompts out of case-XX_*.md files.
_CASE_MD_PROMPT_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"\|\s*起動フレーズ\s*\|\s*\"([^\"]+)\"\s*\|"),
    re.compile(r"\|\s*prompt\s*\|\s*([^|\n]+?)\s*\|", re.IGNORECASE),
    re.compile(r"```text\s*\n([^\n]+)\n```"),
    re.compile(r'^\s*"([^"\n]+)"\s*$', re.MULTILINE),
)

_CASE_MD_EXPECTATION_BLOCK = re.compile(
    r"##\s*期待\s*\n(.+?)(?:\n##\s|\Z)", re.DOTALL
)


def _extract_case_md_prompt(text: str) -> str | None:
    for pattern in _CASE_MD_PROMPT_PATTERNS:
        match = pattern.search(text)
        if match:
            candidate = match.group(1).strip()
            if candidate:
                return candidate
    return None


def _extract_case_md_expectations(text: str) -> list[str]:
    block = _CASE_MD_EXPECTATION_BLOCK.search(text)
    if not block:
        return []
    return [
        line.lstrip("- ").strip()
        for line in block.group(1).splitlines()
        if line.strip().startswith("-")
    ]


def _parse_evals_json(path: Path) -> list[dict[str, Any]]:
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return []
    items = data.get("evals", []) if isinstance(data, dict) else []
    cases: list[dict[str, Any]] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        prompt = (item.get("prompt") or "").strip()
        if not prompt:
            continue
        cases.append(
            {
                "id": str(item.get("id", "")),
                "prompt": prompt,
                "expectations": [
                    str(e)
                    for e in item.get("expectations", [])
                    if isinstance(e, (str, int))
                ],
                "kind": "json",
            }
        )
    return cases


def _parse_case_md_file(path: Path) -> dict[str, Any] | None:
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    prompt = _extract_case_md_prompt(text)
    if not prompt:
        return None
    return {
        "id": path.stem,
        "prompt": prompt,
        "expectations": _extract_case_md_expectations(text),
        "kind": "case_md",
    }


def parse_skill_evals(skill_dir: Path) -> list[dict[str, Any]]:
    """Walk <skill_dir>/evals/ and return a unified list of cases.

    The directory may be missing or empty; in that case an empty list is
    returned. Each parser is fail-open (broken files are skipped).
    """
    evals_dir = skill_dir / "evals"
    if not evals_dir.is_dir():
        return []

    cases: list[dict[str, Any]] = []

    json_path = evals_dir / "evals.json"
    if json_path.is_file():
        cases.extend(_parse_evals_json(json_path))

    for md_path in sorted(evals_dir.glob("case-*.md")):
        parsed = _parse_case_md_file(md_path)
        if parsed:
            cases.append(parsed)

    return cases


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: parse_evals.py <skill_dir>", file=sys.stderr)
        return 2
    cases = parse_skill_evals(Path(argv[1]))
    json.dump(cases, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main(sys.argv))
