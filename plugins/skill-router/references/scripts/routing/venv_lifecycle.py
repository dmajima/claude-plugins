"""venv lifecycle helpers for skill-router hooks.

Policy
------
- Location
    The venv lives under a *user-owned* directory only: ``${CLAUDE_PLUGIN_DATA}``
    when Claude Code provides it, otherwise
    ``~/.claude/.local/plugins/skill-router/``.  Index / config / session data
    may still resolve to a repository-relative base (see
    :func:`build_index.resolve_base_dir`), but the interpreter the hooks
    execute must never be supplied by a checked-out repository: a clone could
    otherwise ship ``.venv/Scripts/python.exe`` and gain code execution on the
    first session.  ``--venv-base`` / ``--base`` override this for tests.

- Construction
    Completion is recorded in ``<venv-base>/.venv-ready`` (the sha256 of the
    requirements file), written only after pip succeeds.  ``ensure`` and
    ``python-bin`` require it, so a tree left behind by a construction that hit
    the SessionStart timeout is rebuilt rather than used.

    A venv is built only when **both** hold: the plugin's
    ``references/scripts/setup/requirements.txt`` lists at least one active
    (non-comment) dependency, *and* the user opted into embedding routing
    (``embedding.enabled = true`` in ``<venv-base>/config.json`` - read from
    the user-owned directory so a repository cannot switch it on).  The default
    configuration disables embedding, so a default install never runs pip and
    never pays the download cost.

- Recovery from a broken venv
    The primary mechanism is the readiness marker (see Construction): a venv
    without a matching ``.venv-ready`` is rebuilt by ``ensure`` on the next
    session, which covers the common case of a construction killed midway.
    ``is-env-error`` below is a secondary path for a venv that looks complete
    but fails at import time; note that ``build_index`` swallows its own
    exceptions, so in practice this fires only for interpreter-level breakage.

- Rebuild on environment error
    Hooks pass the captured stderr through ``is-env-error`` which requires the
    full Python traceback structure (``Traceback (most recent call last):``
    header *and* a terminating ``ModuleNotFoundError`` / ``ImportError`` line).
    This avoids false positives from stray words in unrelated error messages.
    Rebuild is allowed up to ``REBUILD_LIMIT`` (3) times per session, tracked by
    an integer counter in ``<venv-base>/.venv-rebuild-count``.  SessionStart
    resets the counter via ``session-reset``.

    **Important**: the counter is incremented *before* :func:`construct` runs,
    so a failed construction still consumes one of the three attempts.  This is
    intentional - it caps both transient errors and persistent
    misconfigurations under the same budget, preventing a broken environment
    from spinning rebuilds forever.

- Construction backoff
    Consecutive construction failures are recorded in
    ``<venv-base>/.venv-construct-failed``.  After ``CONSTRUCT_FAILURE_LIMIT``
    failures, ``ensure`` stops retrying for ``CONSTRUCT_BACKOFF_HOURS`` so an
    offline or unsupported platform does not burn the full pip timeout on every
    session start.

- Teardown
    A venv unused for longer than ``VENV_TTL_HOURS`` (168 h / 7 days by
    default, overridable via ``venv.ttl_hours`` in ``<venv-base>/config.json``
    with a one-hour floor) is removed
    at the *start* of the SessionStart hook, before ``ensure`` runs.

    "Last used" is the mtime of ``<venv-base>/.venv-last-used``, refreshed by
    the processes that actually run inside the venv (``route.py`` and
    ``build_index.py`` call :func:`touch_last_used_if_active`) and by
    :func:`construct`.  Continuous use therefore keeps the venv alive
    indefinitely; only a real idle period expires it.

    A venv whose marker is missing but whose ``pyvenv.cfg`` is present is
    treated as "adopted": the marker is created and the venv is kept, so an
    install that predates the marker is not torn down on first contact.  A
    directory with neither marker nor ``pyvenv.cfg`` has unknown provenance and
    is removed.

- Concurrency
    :func:`construct` and :func:`teardown` take a best-effort lock
    (``<venv-base>/.venv.lock``) so a second Claude Code window cannot delete a
    venv while the first is executing it.  Stale locks expire after
    ``LOCK_STALE_SECONDS``.

The script is fail-open: any error logs to stderr and exits non-zero only when
the caller explicitly asked for a yes/no answer (e.g. ``is-env-error`` returns
0/1 like a test).  Hooks should always continue regardless.

CLI subcommands
---------------
    ensure              Construct the venv if absent and required.
    rebuild             Force-rebuild the venv (used after an env error).
    cleanup-if-stale    Remove the venv if unused for longer than --ttl-hours.
    touch-last-used     Refresh the last-used marker (diagnostics).
    python-bin          Print the Python executable hooks should use.
                        This is a pure query: it has no side effects.
    prepare             session-reset + cleanup-if-stale + ensure, then print
                        the interpreter.  One process instead of four.
    is-env-error        Exit 0 iff the given stderr file matches an env-error
                        signature, else exit 1.
    session-reset       Clear the per-session rebuild sentinel.

All subcommands accept ``--plugin-root <path>`` to locate the plugin's
``references/scripts/setup/requirements.txt``.  ``--venv-base <path>`` overrides
the venv directory and ``--base`` is an alias for it; both exist for tests and
diagnostics and are not passed by the hooks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Sequence

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import config_io  # noqa: E402  (sibling module)

try:  # session_state is optional for the pure-path helpers used by tests
    from session_state import mask_secrets  # noqa: E402
except Exception:  # pragma: no cover - defensive
    def mask_secrets(text: str | None) -> str | None:
        return text


VENV_DIR_NAME = ".venv"
VENV_TTL_HOURS_DEFAULT = 168  # 7 days, measured from last use (not creation)
VENV_TTL_HOURS_MIN = 1  # floor for the configurable TTL
REBUILD_COUNT_FILE = ".venv-rebuild-count"
LAST_USED_FILE = ".venv-last-used"
FAILURE_STATE_FILE = ".venv-construct-failed"
LOCK_FILE = ".venv.lock"
READY_FILE = ".venv-ready"
REBUILD_LIMIT = 3
CONSTRUCT_FAILURE_LIMIT = 3
CONSTRUCT_BACKOFF_HOURS = 6
LOCK_STALE_SECONDS = 600
_CONSTRUCT_LOG_MAX_BYTES = 262_144  # 256 KiB
# Clocks can disagree (VM snapshots, restored backups).  A marker further than
# this into the future is treated as corrupt and rewritten rather than trusted.
_FUTURE_SKEW_TOLERANCE_SECONDS = 3600

# The marker's *mtime* is the timestamp; the body is written once at
# creation only so that repeated touches stay a metadata-only operation.
_LAST_USED_NOTE = (
    "skill-router venv last-used marker.\n"
    "The mtime of this file is the timestamp used for TTL evaluation.\n"
)
_TRACEBACK_HEADER = "Traceback (most recent call last):"
_ENV_ERROR_TERMINATOR = re.compile(
    r"^(?:[\w\.]+\.)?(ModuleNotFoundError|ImportError)\s*:",
    re.MULTILINE,
)


def is_environment_error(text: str) -> bool:
    """Return True only when ``text`` looks like a Python traceback ending
    in ``ModuleNotFoundError`` / ``ImportError``.

    A bare keyword match is intentionally not enough: we want both the
    traceback header and a terminating exception line, so warnings or
    arbitrary log output that merely mentions ``ImportError`` does not
    trigger a venv rebuild.
    """
    if not text or _TRACEBACK_HEADER not in text:
        return False
    return bool(_ENV_ERROR_TERMINATOR.search(text))


# ---------------------------------------------------------------------------
# Path / state helpers
# ---------------------------------------------------------------------------


def resolve_venv_base() -> Path:
    """Directory that owns the venv and its sentinels.

    Defined in :mod:`config_io` so the router and the indexer can resolve the
    same directory without importing this module on the prompt path.
    """
    return config_io.resolve_venv_base()


def _resolve_venv_base(args: argparse.Namespace) -> Path:
    """Venv directory for this invocation.

    ``--venv-base`` wins, then ``--base`` (both are test / diagnostic
    overrides that the hooks never pass), then the environment.
    """
    override = getattr(args, "venv_base", None) or getattr(args, "base", None)
    if override:
        return Path(override).expanduser()
    return resolve_venv_base()


def venv_dir(base: Path) -> Path:
    return base / VENV_DIR_NAME


def venv_python(base: Path) -> Path:
    vd = venv_dir(base)
    if os.name == "nt":
        return vd / "Scripts" / "python.exe"
    return vd / "bin" / "python"


def venv_pip(base: Path) -> Path:
    vd = venv_dir(base)
    if os.name == "nt":
        return vd / "Scripts" / "pip.exe"
    return vd / "bin" / "pip"


def has_active_requirements(requirements: Path) -> bool:
    """Return True iff ``requirements`` exists and has any non-comment line."""
    if not requirements.is_file():
        return False
    try:
        for line in requirements.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped and not stripped.startswith("#"):
                return True
    except (OSError, UnicodeDecodeError):
        return False
    return False


def embedding_enabled(venv_base: Path) -> bool:
    """Whether the user opted into embedding routing.

    Thin wrapper over :func:`config_io.embedding_enabled` so the venv builder,
    the indexer and the router all share one decision point.
    """
    return config_io.embedding_enabled(venv_base)


def configured_ttl_hours(venv_base: Path) -> float:
    """TTL in hours, overridable via ``venv.ttl_hours`` in config.json.

    Read from the same user-owned location as :func:`embedding_enabled`, and
    clamped: a repository-supplied value of 0.0001 would otherwise force a
    teardown-plus-reinstall on every session.
    """
    try:
        raw = config_io.load_raw_config(venv_base)
        section = raw.get("venv")
        if isinstance(section, dict):
            value = float(section.get("ttl_hours", VENV_TTL_HOURS_DEFAULT))
            if value > 0:
                return max(VENV_TTL_HOURS_MIN, value)
    except Exception:
        pass
    return float(VENV_TTL_HOURS_DEFAULT)


def venv_required(venv_base: Path, requirements: Path) -> bool:
    """Return True iff a venv should exist for this configuration."""
    return has_active_requirements(requirements) and embedding_enabled(venv_base)


def venv_age_seconds(base: Path) -> float | None:
    cfg = venv_dir(base) / "pyvenv.cfg"
    try:
        return time.time() - cfg.stat().st_mtime
    except OSError:
        return None


def venv_ready_path(base: Path) -> Path:
    return base / READY_FILE


def _requirements_fingerprint(requirements: Path) -> str:
    try:
        return hashlib.sha256(requirements.read_bytes()).hexdigest()
    except OSError:
        return ""


def venv_is_ready(base: Path, requirements: Path) -> bool:
    """True when the venv finished installing *these* requirements.

    ``python -m venv`` writes ``pyvenv.cfg`` and the interpreter before pip
    runs, so a construction killed by the SessionStart timeout leaves a tree
    that looks complete but has no dependencies.  The marker is written only
    after pip succeeds, and carries the requirements hash so an edited
    dependency list also forces a rebuild.
    """
    if not (venv_dir(base) / "pyvenv.cfg").exists():
        return False
    if not venv_python(base).exists():
        return False
    try:
        recorded = venv_ready_path(base).read_text(encoding="utf-8").strip()
    except OSError:
        return False
    return bool(recorded) and recorded == _requirements_fingerprint(requirements)


def venv_last_used_path(base: Path) -> Path:
    return base / LAST_USED_FILE


def touch_last_used(base: Path) -> None:
    """Record "the venv was used just now" by bumping the marker's mtime.

    Called by :func:`construct`, by :func:`touch_last_used_if_active` (from the
    processes actually running inside the venv) and by the ``touch-last-used``
    subcommand.  Failures are swallowed: a missed timestamp only delays
    teardown by one TTL window and must never break the prompt path.

    The marker is plugin-owned state, so a symlink in its place is always
    illegitimate - it is replaced rather than followed (a followed link would
    let a repository redirect our writes and mtime updates elsewhere).
    """
    path = venv_last_used_path(base)
    try:
        if path.is_symlink():
            # Replacing (not following) the link is what keeps a repository
            # from redirecting our writes; the utime flag below is only a
            # second line of defence for the race between the two calls.
            path.unlink()
        if path.exists():
            if os.utime in getattr(os, "supports_follow_symlinks", set()):
                os.utime(path, None, follow_symlinks=False)
            else:  # Windows: flag unsupported, the unlink above still applies
                os.utime(path, None)
            return
        base.mkdir(parents=True, exist_ok=True)
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        flags |= getattr(os, "O_NOFOLLOW", 0)
        fd = os.open(path, flags, 0o600)
        try:
            os.write(fd, _LAST_USED_NOTE.encode("utf-8"))
        finally:
            os.close(fd)
    except (OSError, NotImplementedError):
        pass


def touch_last_used_if_active() -> None:
    """Refresh the marker when the caller is running inside the venv.

    ``route.py`` and ``build_index.py`` call this at start-up.  Keeping the
    update here - rather than in ``python-bin`` - means the interpreter query
    stays free of side effects, so hook steps can be reordered without silently
    disabling the TTL.  A no-op when running under the system interpreter.
    """
    try:
        if sys.prefix == getattr(sys, "base_prefix", sys.prefix):
            return
        base = Path(sys.prefix).parent
        if venv_dir(base).resolve() != Path(sys.prefix).resolve():
            return
        touch_last_used(base)
    except Exception:  # pragma: no cover - never break the caller
        pass


def venv_idle_seconds(base: Path) -> float | None:
    """Seconds since the venv was last used.

    Returns ``None`` when there is nothing to evaluate (no venv directory).
    Returns ``inf`` when a directory exists but carries neither the marker nor
    ``pyvenv.cfg``: its provenance is unknown, so it must not be executed and
    should be removed.
    """
    if not venv_dir(base).exists():
        return None
    marker = venv_last_used_path(base)
    try:
        mtime = marker.stat().st_mtime
    except OSError:
        if venv_age_seconds(base) is None:
            return float("inf")
        return None  # adopted below by cmd_cleanup_if_stale
    now = time.time()
    if mtime > now + _FUTURE_SKEW_TOLERANCE_SECONDS:
        # Corrupt / tampered timestamp: rewrite it instead of trusting a value
        # that would freeze the TTL forever.
        touch_last_used(base)
        return 0.0
    idle = max(0.0, now - mtime)
    # A venv cannot have been idle longer than it has existed.  Cross-checking
    # against the creation timestamp means backdating the marker alone cannot
    # trigger a teardown-plus-reinstall cycle.
    age = venv_age_seconds(base)
    if age is not None:
        idle = min(idle, max(0.0, age))
    return idle


def marker_absent_with_venv(base: Path) -> bool:
    """True for a venv that predates the marker (installed by an older build)."""
    return (venv_dir(base).exists()
            and not venv_last_used_path(base).exists()
            and (venv_dir(base) / "pyvenv.cfg").exists())


# ---------------------------------------------------------------------------
# Mutating helpers
# ---------------------------------------------------------------------------


def safe_which(name: str) -> str | None:
    """Locate an executable on PATH, refusing anything under the CWD.

    On Windows ``shutil.which`` searches the process working directory before
    PATH.  The hooks run with the project directory as CWD, so a cloned
    repository shipping ``python3.exe`` would otherwise be handed straight to
    ``subprocess.run`` - bypassing the whole point of keeping the venv out of
    repository-controlled paths.  Anything resolving inside the CWD is
    therefore discarded rather than executed.
    """
    found = shutil.which(name)
    if not found:
        return None
    try:
        resolved = Path(found).resolve()
        cwd = Path.cwd().resolve()
    except OSError:
        return None
    try:
        resolved.relative_to(cwd)
    except ValueError:
        pass  # outside the CWD: acceptable
    else:
        return None
    return str(resolved) if resolved.is_file() else None


def _python_for_subprocess() -> str:
    """Return a python executable that subprocess can launch reliably.

    Some Windows environments (notably pyenv-win) expose ``python3.exe``
    as an App Execution Alias that raises ``WinError 2`` when invoked
    via :func:`subprocess.run`.  Prefer ``python.exe`` colocated with
    ``sys.executable``; fall back to a PATH lookup that excludes the CWD,
    then to ``sys.executable`` itself.
    """
    exe = Path(sys.executable)
    if os.name == "nt":
        sibling = exe.parent / "python.exe"
        if sibling.is_file() and sibling != exe:
            return str(sibling)
    found = safe_which("python") or safe_which("python3")
    if found:
        return found
    return str(exe)


def _record_event(base: Path, message: str) -> None:
    """Append one masked line to the lifecycle log.

    Teardown and construction move ~650 MB around and are otherwise invisible
    (the hooks discard all output), so an operator has no way to tell why a
    venv disappeared.  Bounded and masked like venv-construct.log.
    """
    try:
        base.mkdir(parents=True, exist_ok=True)
        target = base / "venv-lifecycle.log"
        if target.exists() and target.stat().st_size > _CONSTRUCT_LOG_MAX_BYTES:
            target.unlink()
        stamp = time.strftime("%Y-%m-%dT%H:%M:%S")
        # 追記は config_io.open_append 経由（リンク非追従 + 作成時 0600）。
        # open + 後追い chmod だと、その間だけ umask 由来の緩い権限が残る。
        with config_io.open_append(target) as fh:
            fh.write(f"{stamp} {mask_secrets(message)}\n")
    except OSError:
        pass


def _record_failure(base: Path, lines: list[str]) -> None:
    """Append masked construction diagnostics, bounded in size.

    pip echoes the index URL, which can embed credentials, so the same masking
    the router applies to ``error.log`` is applied here.
    """
    try:
        base.mkdir(parents=True, exist_ok=True)
        target = base / "venv-construct.log"
        body = (mask_secrets("\n".join(lines)) or "") + "\n"
        if target.exists() and target.stat().st_size > _CONSTRUCT_LOG_MAX_BYTES:
            target.unlink()
        with config_io.open_append(target) as fh:
            fh.write(body)
    except OSError:
        pass


def _failure_state(base: Path) -> dict[str, Any]:
    try:
        raw = (base / FAILURE_STATE_FILE).read_text(encoding="utf-8")
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _write_failure_state(base: Path, count: int) -> None:
    try:
        base.mkdir(parents=True, exist_ok=True)
        payload = json.dumps({"count": count, "last_attempt": time.time()})
        (base / FAILURE_STATE_FILE).write_text(payload, encoding="utf-8")
    except OSError:
        pass


def _clear_failure_state(base: Path) -> None:
    try:
        (base / FAILURE_STATE_FILE).unlink()
    except OSError:
        pass


def construction_blocked(base: Path) -> bool:
    """True while the backoff window after repeated failures is open."""
    state = _failure_state(base)
    try:
        count = int(state.get("count", 0))
        last = float(state.get("last_attempt", 0))
    except (TypeError, ValueError):
        return False
    if count < CONSTRUCT_FAILURE_LIMIT:
        return False
    return (time.time() - last) < CONSTRUCT_BACKOFF_HOURS * 3600


def _acquire_lock(base: Path) -> int | None:
    """Best-effort exclusive lock.  Returns a file descriptor or None."""
    path = base / LOCK_FILE
    try:
        base.mkdir(parents=True, exist_ok=True)
    except OSError:
        return None
    for _ in range(2):
        try:
            return os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            try:
                if time.time() - path.stat().st_mtime > LOCK_STALE_SECONDS:
                    path.unlink()
                    continue
            except OSError:
                pass
            return None
        except OSError:
            return None
    return None


def _release_lock(base: Path, fd: int | None) -> None:
    if fd is None:
        return
    try:
        os.close(fd)
    except OSError:
        pass
    try:
        (base / LOCK_FILE).unlink()
    except OSError:
        pass


def _remove_marker(base: Path) -> None:
    try:
        venv_last_used_path(base).unlink()
    except OSError:
        pass


def _teardown_unlocked(base: Path) -> bool:
    """Remove the venv directory.  Returns True when nothing is left behind.

    Errors are *not* ignored: a surviving directory would otherwise be treated
    as a freshly built venv by :func:`construct`, which then executes whatever
    ``Scripts/pip.exe`` remains there.
    """
    vd = venv_dir(base)
    ok = True
    if vd.is_symlink():
        # A link is never something we created; drop the link itself and do not
        # recurse into whatever it points at.
        try:
            vd.unlink()
        except OSError:
            ok = False
    elif vd.exists():
        try:
            shutil.rmtree(vd)
        except OSError:
            ok = not vd.exists()
    # Drop the sentinels too: a stale timestamp surviving into the next
    # construct() would make the fresh venv look instantly expired, and a
    # stale ready-marker would make a half-built tree look complete.
    _remove_marker(base)
    try:
        venv_ready_path(base).unlink()
    except OSError:
        pass
    return ok


def teardown(base: Path) -> bool:
    """Locked teardown.  Returns True when the venv directory is gone.

    Returns False without touching anything when the lock is held: another
    session is building or removing this venv, and racing it would leave a
    half-deleted tree behind.
    """
    fd = _acquire_lock(base)
    if fd is None:
        _record_event(base, "teardown skipped: lock held by another session")
        return False
    try:
        removed = _teardown_unlocked(base)
        _record_event(base, f"teardown removed={removed} path={venv_dir(base)}")
        return removed
    finally:
        _release_lock(base, fd)


def construct(base: Path, requirements: Path) -> bool:
    """Create a fresh venv and install requirements.  Returns True on success.

    Failure details are recorded to ``<venv-base>/venv-construct.log`` so the
    operator can diagnose without re-running.
    """
    fd = _acquire_lock(base)
    if fd is None:
        # Another session is building or removing this venv; let it finish.
        return False
    try:
        base.mkdir(parents=True, exist_ok=True)
        log: list[str] = []
        if not _teardown_unlocked(base):
            log.append(f"teardown failed; refusing to build over {venv_dir(base)}")
            _record_failure(base, log)
            _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
            return False
        py = _python_for_subprocess()
        log.append(f"python={py}")
        try:
            result = subprocess.run(
                [py, "-m", "venv", "--clear", str(venv_dir(base))],
                capture_output=True,
                timeout=60,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
            log.append(f"venv-create exception: {exc!r}")
            _record_failure(base, log)
            _teardown_unlocked(base)
            _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
            return False
        if result.returncode != 0:
            log.append(f"venv-create rc={result.returncode}")
            log.append("stderr=" + result.stderr.decode(errors="replace").strip())
            log.append("stdout=" + result.stdout.decode(errors="replace").strip())
            _record_failure(base, log)
            _teardown_unlocked(base)
            _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
            return False

        if has_active_requirements(requirements):
            pip = venv_pip(base)
            if not pip.exists():
                log.append(f"pip not found at {pip}")
                _record_failure(base, log)
                _teardown_unlocked(base)
                _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
                return False
            try:
                result = subprocess.run(
                    _pip_install_argv(pip, requirements),
                    capture_output=True,
                    timeout=180,
                )
            except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
                log.append(f"pip install exception: {exc!r}")
                _record_failure(base, log)
                _teardown_unlocked(base)
                _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
                return False
            if result.returncode != 0:
                log.append(f"pip install rc={result.returncode}")
                log.append("stderr=" + result.stderr.decode(errors="replace").strip())
                _record_failure(base, log)
                _teardown_unlocked(base)
                _write_failure_state(base, int(_failure_state(base).get("count", 0)) + 1)
                return False
        _clear_failure_state(base)
        try:
            venv_ready_path(base).write_text(
                _requirements_fingerprint(requirements), encoding="utf-8")
        except OSError:
            pass
        touch_last_used(base)
        _record_event(base, f"construct succeeded path={venv_dir(base)}")
        return True
    finally:
        _release_lock(base, fd)


def _pip_install_argv(pip: Path, requirements: Path) -> list[str]:
    """Build the pip command, preferring a hash-pinned lock file.

    ``--only-binary=:all:`` keeps sdist ``setup.py`` off the install path; the
    three dependencies publish wheels for every supported platform.
    """
    lock = requirements.with_name("requirements.lock")
    argv = [str(pip), "install", "--quiet", "--disable-pip-version-check",
            "--only-binary=:all:"]
    if lock.is_file():
        return argv + ["--require-hashes", "-r", str(lock)]
    return argv + ["-r", str(requirements)]


# ---------------------------------------------------------------------------
# CLI subcommands
# ---------------------------------------------------------------------------


def _requirements_path(plugin_root: Path) -> Path:
    return plugin_root / "references" / "scripts" / "setup" / "requirements.txt"


def cmd_ensure(args: argparse.Namespace) -> int:
    vbase = _resolve_venv_base(args)
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if not venv_required(vbase, requirements):
        return 0  # stdlib-only phase, or embedding not opted into
    if venv_is_ready(vbase, requirements):
        return 0
    if construction_blocked(vbase):
        return 0  # backoff window after repeated failures
    return 0 if construct(vbase, requirements) else 1


def _read_rebuild_count(base: Path) -> int:
    counter = base / REBUILD_COUNT_FILE
    try:
        return int(counter.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return 0


def _write_rebuild_count(base: Path, value: int) -> None:
    """Atomically write the rebuild counter so concurrent hooks cannot
    observe a half-written file."""
    base.mkdir(parents=True, exist_ok=True)
    target = base / REBUILD_COUNT_FILE
    tmp = base / (REBUILD_COUNT_FILE + ".tmp")
    tmp.write_text(str(value), encoding="utf-8")
    os.replace(tmp, target)


def cmd_rebuild(args: argparse.Namespace) -> int:
    vbase = _resolve_venv_base(args)
    current = _read_rebuild_count(vbase)
    if current >= REBUILD_LIMIT:
        return 2  # exhausted this session's rebuild budget
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if not requirements.is_file():
        # --plugin-root が実際のプラグインを指していない（手動実行での
        # 取り違え等）。「依存なし」と誤判定して健全な venv を撤去しないよう、
        # 判定不能として何もせずに返す。
        return 0
    _write_rebuild_count(vbase, current + 1)
    if not venv_required(vbase, requirements):
        teardown(vbase)
        return 0
    return 0 if construct(vbase, requirements) else 1


def cmd_cleanup_if_stale(args: argparse.Namespace) -> int:
    vbase = _resolve_venv_base(args)
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if not requirements.is_file():
        # --plugin-root が実際のプラグインを指していない（手動実行での
        # 取り違え等）。「依存なし」と誤判定して健全な venv を撤去しないよう、
        # 判定不能として何もせずに返す。
        return 0
    if venv_dir(vbase).exists() and not venv_required(vbase, requirements):
        # The user opted out (or the dependency list went empty): the venv can
        # no longer be reached through any supported path, so hold onto it and
        # its ~650 MB would be pure waste.  TTL is irrelevant here.
        teardown(vbase)
        return 0
    if marker_absent_with_venv(vbase):
        # Built before the marker existed: adopt it instead of forcing every
        # existing install through one teardown + reinstall cycle.
        touch_last_used(vbase)
        return 0
    idle = venv_idle_seconds(vbase)
    if idle is None:
        return 0
    ttl_hours = args.ttl_hours
    if ttl_hours is None:
        ttl_hours = configured_ttl_hours(vbase)
    if idle > ttl_hours * 3600:
        teardown(vbase)
    return 0


def cmd_touch_last_used(args: argparse.Namespace) -> int:
    """Refresh the last-used marker explicitly (diagnostics / manual use)."""
    touch_last_used(_resolve_venv_base(args))
    return 0


def cmd_python_bin(args: argparse.Namespace) -> int:
    """Print the interpreter the hooks should use.  Pure query, no side effects."""
    vbase = _resolve_venv_base(args)
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if venv_required(vbase, requirements):
        if venv_is_ready(vbase, requirements):
            print(str(venv_python(vbase)))
            return 0
        if not args.no_construct and not construction_blocked(vbase):
            if construct(vbase, requirements):
                print(str(venv_python(vbase)))
                return 0
    fallback = (safe_which("python3") or safe_which("python")
                or sys.executable)
    print(fallback)
    return 0


def cmd_prepare(args: argparse.Namespace) -> int:
    """Run the SessionStart lifecycle in order, then print the interpreter.

    Collapses ``session-reset`` -> ``cleanup-if-stale`` -> ``ensure`` ->
    ``python-bin`` into one process.  Each of those costs a fresh interpreter
    start (~0.45 s on Windows), and the ordering constraint between them now
    lives here rather than in the hook script, where a reordering would have
    been silent.
    """
    cmd_session_reset(args)
    cmd_cleanup_if_stale(args)
    cmd_ensure(args)
    return cmd_python_bin(args)


def cmd_is_env_error(args: argparse.Namespace) -> int:
    try:
        text = Path(args.stderr_file).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 1
    return 0 if is_environment_error(text) else 1


def cmd_session_reset(args: argparse.Namespace) -> int:
    counter = _resolve_venv_base(args) / REBUILD_COUNT_FILE
    try:
        counter.unlink()
    except FileNotFoundError:
        pass
    except OSError:
        return 1
    return 0


# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------


def _add_common(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--plugin-root", default=".",
                        help="Plugin root directory (contains references/).")
    parser.add_argument("--base", default=None,
                        help="Alias for --venv-base, kept for diagnostics. "
                             "Overrides the venv directory, not the data dir.")
    parser.add_argument("--venv-base", default=None,
                        help="Override the venv directory (tests / diagnostics "
                             "only; hooks never pass this).")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="venv_lifecycle")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("ensure")
    _add_common(p)
    p.set_defaults(func=cmd_ensure)

    p = sub.add_parser("rebuild")
    _add_common(p)
    p.set_defaults(func=cmd_rebuild)

    p = sub.add_parser("cleanup-if-stale")
    _add_common(p)
    p.add_argument("--ttl-hours", type=float, default=None,
                   help="Override the TTL (default: venv.ttl_hours in "
                        "config.json, else 168).")
    p.set_defaults(func=cmd_cleanup_if_stale)

    p = sub.add_parser("touch-last-used")
    _add_common(p)
    p.set_defaults(func=cmd_touch_last_used)

    p = sub.add_parser("python-bin")
    _add_common(p)
    p.add_argument("--no-construct", action="store_true",
                   help="Do not construct a venv; only return existing one.")
    p.set_defaults(func=cmd_python_bin)

    p = sub.add_parser("prepare")
    _add_common(p)
    p.add_argument("--ttl-hours", type=float, default=None)
    p.set_defaults(func=cmd_prepare, no_construct=True)

    p = sub.add_parser("is-env-error")
    p.add_argument("--stderr-file", required=True)
    p.set_defaults(func=cmd_is_env_error)

    p = sub.add_parser("session-reset")
    _add_common(p)
    p.set_defaults(func=cmd_session_reset)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except Exception:  # pragma: no cover - fail-open
        return 1


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
