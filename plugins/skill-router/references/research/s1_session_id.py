"""Research S1: confirm whether UserPromptSubmit stdin JSON provides session_id.

How to run:
  - Wire this script as a temporary UserPromptSubmit hook (see header docstring).
  - Send a few prompts and check the produced log lines.
  - On success, every record contains a non-empty session_id field, allowing
    the v2 fallback chain in session_state.py to be simplified.

The script reads stdin as JSON, logs presence/absence of the session_id and
transcript_path fields, and always exits 0.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def _log_path() -> Path:
    base = Path(os.environ.get("CLAUDE_PLUGIN_DATA", "")).expanduser()
    if not base or not str(base):
        base = Path.home() / ".claude" / ".local" / "plugins" / "skill-router" / "research"
    base.mkdir(parents=True, exist_ok=True)
    return base / "s1_session_id.log"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        payload = {}
    record = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "has_session_id": bool(payload.get("session_id")),
        "session_id_preview": (payload.get("session_id") or "")[:8],
        "has_transcript_path": bool(payload.get("transcript_path")),
        "hook_event_name": payload.get("hook_event_name"),
        "cwd": payload.get("cwd"),
    }
    try:
        with _log_path().open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
