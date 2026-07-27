"""Session state management for skill-router.

Implements design v2 section 3.3:
  - session_id resolution with the v2 priority order.
  - per-session directory <base>/sessions/<session_id>/ with prompts.jsonl
    and route_decisions.jsonl.
  - tail-read of the last N prompts (default 3) for context continuity.
  - mask_secrets() borrowed from credentials-manager regex set.

The two JSONL files are written one row per turn each, so they line up 1:1;
The ``skill-router`` skill's diagnostic flow (SKILL.md, and eval
``case-24`` Phase 7) reads a missing decision row as "the hook was cut off".
``route.py`` therefore records a ``tier: "skip"`` row for turns that produce no
recommendation instead of writing nothing.

Both files - and the session directory - are created owner-only on POSIX: even
after :func:`mask_secrets` they carry the user's prose, filenames and working
paths, which the default umask would expose to every account on the host.
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

import config_io

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


# Whitelist for session_id directory names: alphanumerics + . _ - only,
# 1..128 chars. Anything outside this set (path separators, '..',
# control characters, NUL bytes, etc.) MUST be replaced with a
# deterministic hash to prevent the value being used to escape the
# <base>/sessions/ subtree (CWE-22 / security review M-1).
_SAFE_SID_RE = re.compile(r"^[A-Za-z0-9._-]{1,128}$")


def _normalise_session_id(sid: str) -> str:
    """Reduce ``sid`` to a path-safe token.

    Returns the input verbatim when it matches the whitelist; otherwise
    returns a deterministic SHA-256 hex digest of the original value so
    callers see a stable id without the risk of path traversal.
    """
    if _SAFE_SID_RE.fullmatch(sid):
        return sid
    return _hash_path(sid)


def resolve_session_id(stdin_payload: dict[str, Any]) -> str:
    """Resolve session_id following v2 section 3.3.3 priority.

    Every return path is funnelled through :func:`_normalise_session_id`
    so an attacker that can influence ``stdin_payload`` /
    ``CLAUDE_SESSION_ID`` cannot inject path-traversal sequences.
    """
    sid = (stdin_payload.get("session_id") or "").strip()
    if sid:
        return _normalise_session_id(sid)
    transcript = (stdin_payload.get("transcript_path") or "").strip()
    if transcript:
        return _hash_path(transcript)
    env_sid = (os.environ.get("CLAUDE_SESSION_ID") or "").strip()
    if env_sid:
        return _normalise_session_id(env_sid)
    seed = "|".join(
        [
            socket.gethostname(),
            os.getcwd(),
            str(int(time.time())),
            str(os.getpid()),
        ]
    )
    return hashlib.sha256(seed.encode("utf-8", errors="replace")).hexdigest()


def _ensure_ignored(base: Path) -> None:
    """Drop a self-ignoring ``.gitignore`` into ``base``.

    ``base`` resolves inside the working repository when Claude Code does not
    provide ``CLAUDE_PLUGIN_DATA``, so prompt history would otherwise be a
    ``git add -A`` away from being committed and pushed.  The plugin cannot
    assume the repository already ignores ``.claude/.local/``.
    """
    marker = base / ".gitignore"
    try:
        # リポジトリが空の .gitignore を同梱すると履歴が追跡対象のまま残るため、
        # `*` を含まない既存ファイルは書き直す。リンクは追従しない。
        config_io.drop_symlink(marker)
        if marker.is_file() and "*" in marker.read_text(
                encoding="utf-8", errors="replace"):
            return
    except (OSError, ValueError):
        # UnicodeDecodeError は ValueError 派生。捕捉しないと、不正なバイト列の
        # .gitignore を同梱されただけで、以降の全プロンプトが無音で推奨なしに
        # なる（例外が route() の外まで抜けるため）。
        return
    try:
        base.mkdir(parents=True, exist_ok=True)
        # `<base>` への書き込みは config_io の 2 関数に一本化する。
        with config_io.open_write(marker) as fh:
            fh.write("# skill-router local data; never commit.\n*\n")
    except OSError:
        pass


def session_dir(base: Path, session_id: str) -> Path:
    """Return the per-session directory, creating it on demand.

    Refuses to follow a symlinked ``sessions`` directory: ``base`` can resolve
    inside a checked-out repository, and a link there would redirect the prompt
    history somewhere the user did not choose (a tracked directory, another
    project, ...).  The link is replaced rather than followed.
    """
    _ensure_ignored(base)
    root = base / "sessions"
    if root.is_symlink():
        try:
            root.unlink()
        except OSError:
            pass
    # `is_symlink()` は Windows のジャンクションを検出しないため、実体比較も
    # 併用する。実体が別の場所を指す場合は履歴を書かない（呼び出し側は
    # OSError をフェイルオープンで扱う）。
    if config_io.is_reparse_point(root):
        raise OSError(f"sessions directory is a reparse point: {root}")
    target = root / session_id
    if target.is_symlink():
        # `<sid>` は Claude Code 供給の予測困難な値のため、リポジトリが先回りして
        # リンクを置く経路は現状ないが、`sessions` 親と同じ扱いで揃えておく。
        try:
            target.unlink()
        except OSError:
            pass
    root.mkdir(parents=True, exist_ok=True)
    # プロンプト履歴は利用者のコンテンツであり、共有ホストでは既定 umask の
    # 0755 で他アカウントから読める。mode は umask でビットが落ちるだけなので、
    # 作成時指定なら chmod と違って緩い時間窓が生じない（Windows では無視される）。
    target.mkdir(mode=0o700, exist_ok=True)
    return target


def _append_jsonl(path: Path, record: dict[str, Any]) -> None:
    """Append one JSON record.

    ``mask_secrets`` removes credential-shaped tokens but not the prose,
    filenames and working paths the user typed, so the history stays sensitive.
    :func:`config_io.open_append` creates the file owner-only at ``os.open``
    time; a create-then-``chmod`` sequence would leave it readable under the
    process umask for the window in between.
    """
    with config_io.open_append(path) as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


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
        _append_jsonl(session_dir(base, session_id) / "prompts.jsonl", record)
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
        _append_jsonl(
            session_dir(base, session_id) / "route_decisions.jsonl", record)
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
