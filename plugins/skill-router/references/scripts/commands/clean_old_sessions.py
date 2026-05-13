"""Delete <base>/sessions/<sid>/ directories older than 30 days.

Invoked by /router-status --clean. Required environment: PYTHONUTF8=1
(provided by Claude Code settings.json env). All paths are local user data.

Usage:
    python clean_old_sessions.py <base>

Exit 0 always (fail-open): unrecoverable errors are printed to stderr but the
surrounding /router-status flow must continue.
"""
from __future__ import annotations

import shutil
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
sys.stderr.reconfigure(encoding="utf-8")

_AGE_THRESHOLD_SECONDS = 30 * 24 * 60 * 60  # 30 days


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: clean_old_sessions.py <base>", file=sys.stderr)
        return 0

    base = Path(argv[1])
    sessions_root = base / "sessions"
    if not sessions_root.is_dir():
        print(f"clean_old_sessions: nothing to do (no {sessions_root})")
        return 0

    now = time.time()
    removed = 0
    for entry in sessions_root.glob("*"):
        if not entry.is_dir():
            continue
        try:
            age = now - entry.stat().st_mtime
        except OSError:
            continue
        if age <= _AGE_THRESHOLD_SECONDS:
            continue
        shutil.rmtree(entry, ignore_errors=True)
        removed += 1

    print(f"clean_old_sessions: removed {removed} session(s) older than 30 days")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
