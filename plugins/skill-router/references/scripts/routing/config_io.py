"""Shared ``config.json`` loader used by build_index and route.

Both SessionStart (`build_index.py`) and UserPromptSubmit (`route.py`)
need to inspect the user's `<base>/config.json`.  Earlier versions
duplicated the read logic with comments cross-referencing each other
("Kept separate to avoid a circular import").  This module breaks the
cycle by depending on neither side: it only performs JSON I/O, returns
plain dicts, and lets the caller merge with whatever defaults it owns.

Both base directories are resolved here as well.  They are a matched pair -
``<base>`` may resolve inside a checked-out repository, ``<venv-base>`` never
does - and keeping the two resolvers apart (one here, one in the indexer) was
what forced the prompt path to import ``build_index``.

Public surface:

- :func:`resolve_base_dir()` -> Path
    Directory holding the index, config, session history and logs.
- :func:`resolve_venv_base()` -> Path
    The user-owned directory that owns the venv and the settings which can
    trigger a dependency install.
- :func:`embedding_section(venv_base=None)` -> dict
    The ``embedding`` block, read from that directory only.
- :func:`embedding_enabled(venv_base=None)` -> bool
- :func:`load_raw_config(base)` -> dict
    Read ``<base>/config.json`` and return the top-level dict, or ``{}``
    on missing / malformed input.
- :func:`merge(default, override)` -> dict
    Deep-merge two configuration dicts (override wins on leaf
    conflicts, both sides recursed for nested dicts).
"""
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


# `<base>/config.json` の読み込み上限。設定ファイルとして現実的な値を
# 大きく上回るものは、内容を見るまでもなく無視する。
_MAX_CONFIG_BYTES = 1_048_576  # 1 MiB


def drop_symlink(path: Path) -> None:
    """Remove a symlink standing where we are about to write.

    ``<base>`` can resolve inside a checked-out repository, so any leaf there
    may be a link the clone planted.  Following it would let the repository
    choose which file we append to, truncate or overwrite - including files
    outside the repository.  The link is removed rather than followed; the
    caller then creates a regular file in its place.
    """
    try:
        if path.is_symlink():
            path.unlink()
    except OSError:
        pass


def is_reparse_point(path: Path) -> bool:
    """True when ``path`` resolves somewhere other than where it sits.

    ``Path.is_symlink()`` does not report Windows junctions, which a
    repository checkout can carry into ``<base>``.  Comparing the resolved
    path against ``parent.resolve() / name`` catches those: both sides go
    through ``resolve()``, so 8.3 short names and case normalise identically
    and only a real redirection makes them differ.  Comparing against
    ``absolute()`` instead would report every path below a directory whose
    name is stored in 8.3 short form (``SOMEUSR~1`` and the like) as
    redirected, which silently disables every write under it.
    """
    try:
        if path.is_symlink():
            return True
        if not path.exists():
            return False
        return path.resolve() != (path.parent.resolve() / path.name)
    except OSError:
        return True


def open_append(path: Path, encoding: str = "utf-8"):
    """Open ``path`` for appending inside ``<base>``, never following a link.

    **Every append into ``<base>`` must go through here.**  The directory can
    resolve inside a checked-out repository, so a link planted at the leaf
    redirects the write to a file of the repository's choosing - including one
    outside the repository.  Requiring one helper is what keeps a new call site
    from forgetting the guard; the ``build_index`` error log did exactly that
    while three sibling call sites had it.

    The file is created owner-only on POSIX via the ``mode`` argument of
    :func:`os.open`, which applies at creation time.  A ``open()`` +
    ``os.chmod()`` sequence would leave the file readable under the process
    umask for the window in between.  The mode is ignored for an existing file,
    so an operator who deliberately widened it is not overridden.
    """
    drop_symlink(path)
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND
    # O_NOFOLLOW closes the race between drop_symlink and this open.
    flags |= getattr(os, "O_NOFOLLOW", 0)
    fd = os.open(path, flags, 0o600)
    return os.fdopen(fd, "a", encoding=encoding)


def open_write(path: Path, binary: bool = False, encoding: str = "utf-8"):
    """Open ``path`` for truncating writes inside ``<base>``, never via a link.

    The counterpart of :func:`open_append`, and subject to the same rule:
    **every write into ``<base>`` must go through one of the two.**  Truncation
    is the more destructive of the pair - a link planted at the leaf lets a
    repository pick a file to empty and overwrite - and a write path added
    later is exactly how the guard gets missed.

    Created owner-only on POSIX via the ``mode`` argument of :func:`os.open`,
    which applies at creation time and therefore leaves no umask window.
    """
    drop_symlink(path)
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    flags |= getattr(os, "O_NOFOLLOW", 0)
    if binary:
        flags |= getattr(os, "O_BINARY", 0)
    fd = os.open(path, flags, 0o600)
    return os.fdopen(fd, "wb" if binary else "w",
                     **({} if binary else {"encoding": encoding}))


def sanitise_for_log(value: object, limit: int = 200) -> str:
    """Make an untrusted value safe to put in a log line.

    Keys read from a repository's settings.json can contain newlines, which
    would otherwise let the repository forge arbitrary log records (CWE-117).
    """
    text = str(value)
    escaped = text.encode("unicode_escape").decode("ascii", errors="replace")
    return escaped[:limit]


def _project_root(start: Path) -> Path | None:
    """Walk up from `start` looking for .git, stopping at HOME boundary."""
    home = Path(os.path.expanduser("~")).resolve()
    cur = start.resolve()
    while True:
        if (cur / ".git").exists():
            return cur
        if cur == cur.parent or cur == home:
            return None
        cur = cur.parent


def _has_symlink_component(path: Path) -> bool:
    """True when ``path`` or any existing ancestor is a symlink.

    ``<base>`` can resolve inside a checked-out repository, and every log /
    index / session file is written through it.  A repository that ships
    ``.claude/.local`` (or a file below it) as a link to e.g. ``~/.bashrc``
    would otherwise have our writes redirected outside the repository.
    """
    current = path
    for _ in range(64):  # bounded walk; deep nesting is not a real case
        try:
            if current.is_symlink():
                return True
        except OSError:
            return True
        if current.parent == current:
            return False
        current = current.parent
    return True


def resolve_base_dir() -> Path:
    """Directory holding the index, config, session history and logs.

    Resolution order documented in design v2 section 4.4, and kept in lock-step
    with ``resolve_base.sh``'s ``skill_router_base``.

    The repository tier is skipped when it contains a symlink component, so a
    clone cannot redirect the plugin's writes outside its own tree.
    """
    plugin_data = os.environ.get("CLAUDE_PLUGIN_DATA", "").strip()
    if plugin_data:
        # resolve_venv_base / resolve_base.sh と同じ正規化。
        # 揃えないと "~/x" のような値で 3 実装が別のディレクトリを指す。
        candidate = Path(plugin_data).expanduser()
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            if os.access(candidate, os.W_OK):
                return candidate
        except OSError:
            pass

    project = _project_root(Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())))
    if project is not None:
        candidate = project / ".claude" / ".local" / "plugins" / "skill-router"
        if not _has_symlink_component(candidate):
            return candidate

    return Path(os.path.expanduser("~")) / ".claude" / ".local" / "plugins" / "skill-router"


def resolve_venv_base() -> Path:
    """Directory that owns the venv, its sentinels and the settings that

    can trigger a dependency install.  Deliberately narrower than
    :func:`resolve_base_dir`: the repository-relative tier is skipped so a
    cloned repository can neither supply the interpreter the hooks execute nor
    switch on a ~650 MB install.

    Defined alongside :func:`resolve_base_dir` because the two are a matched
    pair: the difference between them *is* the security boundary, and a change
    to one that is not mirrored in the other erases it.
    """
    plugin_data = os.environ.get("CLAUDE_PLUGIN_DATA", "").strip()
    if plugin_data:
        candidate = Path(plugin_data).expanduser()
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            if os.access(candidate, os.W_OK):
                return candidate
        except OSError:
            pass
    return (Path(os.path.expanduser("~")) / ".claude" / ".local"
            / "plugins" / "skill-router")


def embedding_section(venv_base: Path | None = None) -> dict[str, Any]:
    """Return the whole ``embedding`` block from ``<venv-base>/config.json``.

    The block is owned by the venv base in its entirety - not just the
    ``enabled`` switch - because every key in it (model, cache_dir, weight)
    only has meaning once the dependencies are installed, and splitting the
    ownership let a configuration exist where the venv was built but the
    feature stayed off.
    """
    base = venv_base if venv_base is not None else resolve_venv_base()
    try:
        section = load_raw_config(base).get("embedding")
    except Exception:
        return {}
    return section if isinstance(section, dict) else {}


def embedding_enabled(venv_base: Path | None = None) -> bool:
    """Return True iff the user opted into embedding routing.

    Convenience wrapper over :func:`embedding_section` used by the venv
    builder; the indexer and the router read the whole section instead.  All
    three therefore resolve the flag from one file, so a configuration that
    turns embedding on always also builds the venv it needs.  It is read from
    ``<venv-base>/config.json`` only.  Any read error means "disabled" -
    failing towards *not* installing is the safe direction.
    """
    return bool(embedding_section(venv_base).get("enabled", False))


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
        # `<base>` はリポジトリ供給されうる。巨大な config.json を同梱されると
        # プロンプトごとに全読み込みが走る（index 側には既に 4 MiB 上限がある）。
        # 設定として現実的な上限で足切りする。
        if path.stat().st_size > _MAX_CONFIG_BYTES:
            return {}
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError, RecursionError):
        # 深くネストした JSON は json のパーサが再帰で処理するため
        # RecursionError（RuntimeError 派生であって OSError ではない）になる。
        # サイズ上限では防げない（2000 段で約 10 KB）。
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
