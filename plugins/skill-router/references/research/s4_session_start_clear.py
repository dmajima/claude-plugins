"""Research S4: verify that SessionStart matcher='clear' actually fires on /clear.

Wire this script as a SessionStart hook with matcher 'startup|resume|clear'
(temporary local hooks.json).  It records each invocation with the
hook_event_name + matcher payload so a /clear sequence can be tested end-to-end.

Expected log progression for a typical session:
  startup -> /clear -> clear -> resume(?)

If 'clear' never appears, design v2 D1/H2 must adjust to a manual
/router-rebuild fallback.
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def _log_path() -> Path:
    base = Path(os.environ.get("CLAUDE_PLUGIN_DATA", "")).expanduser()
    if not str(base):
        base = Path.home() / ".claude" / ".local" / "plugins" / "skill-router" / "research"
    base.mkdir(parents=True, exist_ok=True)
    return base / "s4_session_start_clear.log"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        payload = {}
    record = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "hook_event_name": payload.get("hook_event_name"),
        "matcher_value": payload.get("matcher"),
        "session_id_preview": (payload.get("session_id") or "")[:8],
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
