"""venv lifecycle helpers for skill-router hooks.

Policy
------
- Construction
    The venv is created at ``<base>/.venv`` (where ``<base>`` is resolved by
    :func:`build_index.resolve_base_dir`) when it does not yet exist *and*
    ``references/scripts/setup/requirements.txt`` lists at least one active
    (non-comment) dependency.  Stdlib-only Phase 1 therefore skips
    construction entirely.

- Rebuild on environment error
    Hooks pass the captured stderr through ``is-env-error`` which requires
    the full Python traceback structure (``Traceback (most recent call
    last):`` header *and* a terminating ``ModuleNotFoundError`` /
    ``ImportError`` line).  This avoids false positives from stray words
    in unrelated error messages.  Rebuild is allowed up to
    ``REBUILD_LIMIT`` (3) times per session, tracked by an integer
    counter in ``<base>/.venv-rebuild-count``.  SessionStart resets the
    counter via ``session-reset``.

- Teardown
    A venv whose ``pyvenv.cfg`` mtime is older than ``VENV_TTL_HOURS`` (72 h
    by default) is removed at the end of the *UserPromptSubmit* hook
    (the plugin's most frequent activity boundary), so the next
    activity rebuilds it from scratch when needed.

The script is fail-open: any error logs to stderr and exits non-zero only
when the caller explicitly asked for a yes/no answer (e.g. ``is-env-error``
returns 0/1 like a test).  Hooks should always continue regardless.

CLI subcommands
---------------
    ensure              Construct the venv if absent and deps are active.
    rebuild             Force-rebuild the venv (used after an env error).
    cleanup-if-stale    Remove the venv if older than --ttl-hours.
    python-bin          Print the Python executable hooks should use.
    is-env-error        Exit 0 iff the given stderr file matches an env-error
                        signature, else exit 1.
    session-reset       Clear the per-session rebuild sentinel.

All subcommands accept ``--plugin-root <path>`` to locate the plugin's
``references/scripts/setup/requirements.txt``.  ``--base <path>`` overrides
the auto-resolved data dir (used by tests).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Sequence

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

from build_index import resolve_base_dir  # noqa: E402  (sibling module)


VENV_DIR_NAME = ".venv"
VENV_TTL_HOURS_DEFAULT = 72
REBUILD_COUNT_FILE = ".venv-rebuild-count"
REBUILD_LIMIT = 3
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


def _resolve_base(override: str | None) -> Path:
    return Path(override).expanduser() if override else resolve_base_dir()


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
    except OSError:
        return False
    return False


def venv_age_seconds(base: Path) -> float | None:
    cfg = venv_dir(base) / "pyvenv.cfg"
    try:
        return time.time() - cfg.stat().st_mtime
    except OSError:
        return None


# ---------------------------------------------------------------------------
# Mutating helpers
# ---------------------------------------------------------------------------


def _python_for_subprocess() -> str:
    """Return a python executable that subprocess can launch reliably.

    Some Windows environments (notably pyenv-win) expose ``python3.exe``
    as an App Execution Alias that raises ``WinError 2`` when invoked
    via :func:`subprocess.run`.  Prefer ``python.exe`` colocated with
    ``sys.executable``; fall back to a PATH lookup, then to
    ``sys.executable`` itself.
    """
    exe = Path(sys.executable)
    if os.name == "nt":
        sibling = exe.parent / "python.exe"
        if sibling.is_file() and sibling != exe:
            return str(sibling)
    found = shutil.which("python") or shutil.which("python3")
    if found and Path(found).is_file():
        return found
    return str(exe)


def _record_failure(base: Path, lines: list[str]) -> None:
    try:
        base.mkdir(parents=True, exist_ok=True)
        (base / "venv-construct.log").write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        )
    except OSError:
        pass


def construct(base: Path, requirements: Path) -> bool:
    """Create a fresh venv and install requirements.  Returns True on success.

    Failure details are recorded to ``<base>/venv-construct.log`` so the
    operator can diagnose without re-running.
    """
    base.mkdir(parents=True, exist_ok=True)
    teardown(base)
    log: list[str] = []
    py = _python_for_subprocess()
    log.append(f"python={py}")
    try:
        result = subprocess.run(
            [py, "-m", "venv", str(venv_dir(base))],
            capture_output=True,
            timeout=60,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        log.append(f"venv-create exception: {exc!r}")
        _record_failure(base, log)
        teardown(base)
        return False
    if result.returncode != 0:
        log.append(f"venv-create rc={result.returncode}")
        log.append("stderr=" + result.stderr.decode(errors="replace").strip())
        log.append("stdout=" + result.stdout.decode(errors="replace").strip())
        _record_failure(base, log)
        teardown(base)
        return False

    if has_active_requirements(requirements):
        pip = venv_pip(base)
        if not pip.exists():
            log.append(f"pip not found at {pip}")
            _record_failure(base, log)
            teardown(base)
            return False
        try:
            result = subprocess.run(
                [str(pip), "install", "--quiet", "--disable-pip-version-check",
                 "-r", str(requirements)],
                capture_output=True,
                timeout=180,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
            log.append(f"pip install exception: {exc!r}")
            _record_failure(base, log)
            teardown(base)
            return False
        if result.returncode != 0:
            log.append(f"pip install rc={result.returncode}")
            log.append("stderr=" + result.stderr.decode(errors="replace").strip())
            _record_failure(base, log)
            teardown(base)
            return False
    return True


def teardown(base: Path) -> None:
    vd = venv_dir(base)
    if vd.exists():
        shutil.rmtree(vd, ignore_errors=True)


# ---------------------------------------------------------------------------
# CLI subcommands
# ---------------------------------------------------------------------------


def _requirements_path(plugin_root: Path) -> Path:
    return plugin_root / "references" / "scripts" / "setup" / "requirements.txt"


def cmd_ensure(args: argparse.Namespace) -> int:
    base = _resolve_base(args.base)
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if not has_active_requirements(requirements):
        return 0  # no-op for stdlib-only phase
    if venv_python(base).exists():
        return 0
    return 0 if construct(base, requirements) else 1


def _read_rebuild_count(base: Path) -> int:
    counter = base / REBUILD_COUNT_FILE
    try:
        return int(counter.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return 0


def _write_rebuild_count(base: Path, value: int) -> None:
    base.mkdir(parents=True, exist_ok=True)
    (base / REBUILD_COUNT_FILE).write_text(str(value), encoding="utf-8")


def cmd_rebuild(args: argparse.Namespace) -> int:
    base = _resolve_base(args.base)
    current = _read_rebuild_count(base)
    if current >= REBUILD_LIMIT:
        return 2  # exhausted this session's rebuild budget
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    _write_rebuild_count(base, current + 1)
    if not has_active_requirements(requirements):
        teardown(base)
        return 0
    return 0 if construct(base, requirements) else 1


def cmd_cleanup_if_stale(args: argparse.Namespace) -> int:
    base = _resolve_base(args.base)
    age = venv_age_seconds(base)
    if age is None:
        return 0
    if age > args.ttl_hours * 3600:
        teardown(base)
    return 0


def cmd_python_bin(args: argparse.Namespace) -> int:
    base = _resolve_base(args.base)
    requirements = _requirements_path(Path(args.plugin_root).expanduser())
    if has_active_requirements(requirements):
        py = venv_python(base)
        if py.exists():
            print(str(py))
            return 0
        if not args.no_construct:
            if construct(base, requirements):
                print(str(venv_python(base)))
                return 0
    fallback = (shutil.which("python3") or shutil.which("python")
                or sys.executable)
    print(fallback)
    return 0


def cmd_is_env_error(args: argparse.Namespace) -> int:
    try:
        text = Path(args.stderr_file).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 1
    return 0 if is_environment_error(text) else 1


def cmd_session_reset(args: argparse.Namespace) -> int:
    base = _resolve_base(args.base)
    counter = base / REBUILD_COUNT_FILE
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
                        help="Override the auto-resolved data base directory.")


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
    p.add_argument("--ttl-hours", type=float, default=VENV_TTL_HOURS_DEFAULT)
    p.set_defaults(func=cmd_cleanup_if_stale)

    p = sub.add_parser("python-bin")
    _add_common(p)
    p.add_argument("--no-construct", action="store_true",
                   help="Do not construct a venv; only return existing one.")
    p.set_defaults(func=cmd_python_bin)

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
