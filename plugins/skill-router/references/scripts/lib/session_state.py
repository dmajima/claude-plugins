"""Session state management for skill-router.

Implements design v2 section 3.3:
  - session_id resolution with the v2 priority order.
  - per-session directory <base>/sessions/<session_id>/ with prompts.jsonl
    and route_decisions.jsonl.
  - tail-read of the last N prompts (default 3) for context continuity.
  - mask_secrets() borrowed from credentials-manager regex set.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import socket
import sys
import time
from collections import deque
from pathlib import Path
from typing import Any, Iterable

# Regexes loosely aligned with credentials-manager. Kept inline to satisfy the
# "stdlib only" constraint until the shared module promised in design v2 section 10.4
# is implemented.
_SECRET_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"sk-[A-Za-z0-9]{16,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"xox[bpars]-[A-Za-z0-9-]{10,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"AIza[0-9A-Za-z_-]{35}"),
    re.compile(r"glpat-[A-Za-z0-9_-]{20,}"),
    re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"),
    re.compile(r"Bearer\s+[A-Za-z0-9._\-]{16,}", re.IGNORECASE),
    re.compile(r"Basic\s+[A-Za-z0-9+/=]{16,}", re.IGNORECASE),
)


def mask_secrets(text: str | None) -> str | None:
    """Replace any matched secret with the first 4 chars + '***' + last 4.

    Returns the input unchanged for ``None`` and empty-string inputs so the
    caller's type expectation matches the actual runtime contract.  Previously
    the annotation was ``(text: str) -> str`` while the implementation handled
    ``None`` via ``if not text: return text``; the discrepancy showed up in
    mypy strict mode and confused readers (impl review M-9).
    """
    if not text:
        return text
    masked = text
    for pattern in _SECRET_PATTERNS:
        def _sub(match: re.Match[str]) -> str:
            value = match.group(0)
            if len(value) <= 8:
                return "***"
            return f"{value[:4]}***{value[-4:]}"

        masked = pattern.sub(_sub, masked)
    return masked


def _hash_path(path: str) -> str:
    return hashlib.sha256(path.encode("utf-8", errors="replace")).hexdigest()


def resolve_session_id(stdin_payload: dict[str, Any]) -> str:
    """Resolve session_id following v2 section 3.3.3 priority."""
    sid = (stdin_payload.get("session_id") or "").strip()
    if sid:
        return sid
    transcript = (stdin_payload.get("transcript_path") or "").strip()
    if transcript:
        return _hash_path(transcript)
    env_sid = (os.environ.get("CLAUDE_SESSION_ID") or "").strip()
    if env_sid:
        return env_sid
    seed = "|".join(
        [
            socket.gethostname(),
            os.getcwd(),
            str(int(time.time())),
            str(os.getpid()),
        ]
    )
    return hashlib.sha256(seed.encode("utf-8", errors="replace")).hexdigest()


def session_dir(base: Path, session_id: str) -> Path:
    """Return the per-session directory, creating it on demand."""
    target = base / "sessions" / session_id
    target.mkdir(parents=True, exist_ok=True)
    return target


def append_prompt(base: Path, session_id: str, payload: dict[str, Any]) -> None:
    """Append a sanitized record to prompts.jsonl. Fail-open.

    Both ``prompt`` and ``cwd`` pass through ``mask_secrets`` because a
    cwd value can carry a path under e.g. ``.../credentials/...`` or
    similar that an operator pasted token-bearing fragments into
    (security review M-2 / CWE-532).
    """
    try:
        cwd = payload.get("cwd")
        if isinstance(cwd, str):
            cwd = mask_secrets(cwd)
        record = {
            "ts": time.time(),
            "session_id": session_id,
            "prompt": mask_secrets(payload.get("prompt", "")),
            "cwd": cwd,
        }
        path = session_dir(base, session_id) / "prompts.jsonl"
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError:
        return


def append_route_decision(
    base: Path,
    session_id: str,
    decision: dict[str, Any],
) -> None:
    """Append a routing decision record. Fail-open."""
    try:
        record = {"ts": time.time(), "session_id": session_id, **decision}
        path = session_dir(base, session_id) / "route_decisions.jsonl"
        with path.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError:
        return


def tail_recent_prompts(
    base: Path, session_id: str, n: int = 3
) -> list[dict[str, Any]]:
    """Read the last n prompts. Returns [] on missing file."""
    path = base / "sessions" / session_id / "prompts.jsonl"
    if not path.is_file() or n <= 0:
        return []
    try:
        with path.open("r", encoding="utf-8") as fh:
            tail = list(_iter_tail(fh, n))
    except OSError:
        return []
    out: list[dict[str, Any]] = []
    for line in tail:
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return out


def _iter_tail(fh: Iterable[str], n: int) -> list[str]:
    """Return the last ``n`` lines of ``fh`` as a list (newline-stripped).

    Uses :class:`collections.deque` with ``maxlen=n`` so the trim is O(1)
    per line instead of O(N) ``list.pop(0)``.  This keeps
    ``tail_recent_prompts`` cheap even for long-running sessions where
    ``prompts.jsonl`` grows to thousands of lines (impl review M-10).
    """
    if n <= 0:
        return []
    buf: deque[str] = deque(maxlen=n)
    for line in fh:
        buf.append(line.rstrip("\n"))
    return list(buf)


if __name__ == "__main__":
    # Diagnostic dump used by /router-status; not for hook execution.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    payload = {"session_id": os.environ.get("CLAUDE_SESSION_ID", "")}
    print("resolved session_id:", resolve_session_id(payload))
