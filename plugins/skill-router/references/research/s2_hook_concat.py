"""Spike S2: observe how Claude Code merges additionalContext from multiple hooks.

The script can play either of two roles, selected by the --role flag, so a
single file can be wired up as two independent UserPromptSubmit hooks for
back-to-back firing.

Usage in hooks.json (temporary, local only):

  "UserPromptSubmit": [
    {"hooks": [{"type": "command", "command": "python s2_hook_concat.py --role A"}]},
    {"hooks": [{"type": "command", "command": "python s2_hook_concat.py --role B"}]}
  ]

Each invocation writes to the spike log, then emits a hookSpecificOutput with
a clearly identifiable additionalContext line.  Inspect the next assistant
turn to determine: are both lines present? in order? prefixed correctly?
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def _log_path() -> Path:
    base = Path(os.environ.get("CLAUDE_PLUGIN_DATA", "")).expanduser()
    if not str(base):
        base = Path.home() / ".claude" / ".local" / "plugins" / "skill-router" / "spike"
    base.mkdir(parents=True, exist_ok=True)
    return base / "s2_hook_concat.log"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", required=True, choices=["A", "B"])
    args = parser.parse_args()

    try:
        json.load(sys.stdin)  # drain stdin so Claude Code does not block
    except (json.JSONDecodeError, ValueError):
        pass

    marker = f"[s2-role-{args.role}] hook payload {datetime.now(timezone.utc).isoformat()}"
    try:
        with _log_path().open("a", encoding="utf-8") as fh:
            fh.write(marker + "\n")
    except OSError:
        pass

    payload = {
        "continue": True,
        "suppressOutput": True,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": marker,
        },
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
