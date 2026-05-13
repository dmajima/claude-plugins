"""Shared ``config.json`` loader used by build_index and route.

Both SessionStart (`build_index.py`) and UserPromptSubmit (`route.py`)
need to inspect the user's `<base>/config.json`.  Earlier versions
duplicated the read logic with comments cross-referencing each other
("Kept separate to avoid a circular import").  This module breaks the
cycle by depending on neither side: it only performs JSON I/O, returns
plain dicts, and lets the caller merge with whatever defaults it owns.

Public surface:

- :func:`load_raw_config(base)` -> dict
    Read ``<base>/config.json`` and return the top-level dict, or ``{}``
    on missing / malformed input.
- :func:`merge(default, override)` -> dict
    Deep-merge two configuration dicts (override wins on leaf
    conflicts, both sides recursed for nested dicts).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_raw_config(base: Path) -> dict[str, Any]:
    """Return the raw ``<base>/config.json`` as a dict, or ``{}`` on miss/error.

    Does **not** apply defaults; the caller owns its own default schema.
    Fail-open semantics: any IOError or JSON decode error returns ``{}``
    so the heuristic path remains usable.
    """
    path = base / "config.json"
    if not path.is_file():
        return {}
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def merge(default: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge ``override`` on top of ``default``.

    Returns a new dict; inputs are not mutated.  Nested dicts are
    merged recursively; lists and scalars are overwritten wholesale.
    Non-dict ``override`` values short-circuit and replace the
    corresponding default entry as-is.
    """
    out = dict(default)
    for key, val in override.items():
        if key in out and isinstance(out[key], dict) and isinstance(val, dict):
            out[key] = merge(out[key], val)
        else:
            out[key] = val
    return out
