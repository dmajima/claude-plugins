"""Unit tests for venv_lifecycle.

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_venv_lifecycle.py
"""
from __future__ import annotations

import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

_LIB = (
    Path(__file__).resolve().parent.parent
    / "references"
    / "scripts"
    / "lib"
)
sys.path.insert(0, str(_LIB))

import venv_lifecycle  # noqa: E402


class HasActiveRequirementsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.req = Path(self._tmp.name) / "requirements.txt"

    def test_missing_file(self) -> None:
        self.assertFalse(venv_lifecycle.has_active_requirements(self.req))

    def test_only_comments_and_blanks(self) -> None:
        self.req.write_text("# comment\n\n  # indented\n", encoding="utf-8")
        self.assertFalse(venv_lifecycle.has_active_requirements(self.req))

    def test_has_dependency(self) -> None:
        self.req.write_text("# header\nrequests==2.31.0\n", encoding="utf-8")
        self.assertTrue(venv_lifecycle.has_active_requirements(self.req))

    def test_dependency_with_inline_comment(self) -> None:
        self.req.write_text("requests  # pinned\n", encoding="utf-8")
        self.assertTrue(venv_lifecycle.has_active_requirements(self.req))


class VenvAgeTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        venv_lifecycle.venv_dir(self.base).mkdir()

    def test_no_pyvenv_cfg_returns_none(self) -> None:
        self.assertIsNone(venv_lifecycle.venv_age_seconds(self.base))

    def test_recent_age_is_small(self) -> None:
        cfg = venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg"
        cfg.write_text("home = /usr\n", encoding="utf-8")
        age = venv_lifecycle.venv_age_seconds(self.base)
        self.assertIsNotNone(age)
        self.assertLess(age, 5)

    def test_stale_age_is_large(self) -> None:
        cfg = venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg"
        cfg.write_text("home = /usr\n", encoding="utf-8")
        # Backdate by 100 hours
        old = time.time() - 100 * 3600
        os.utime(cfg, (old, old))
        age = venv_lifecycle.venv_age_seconds(self.base)
        self.assertGreater(age, 99 * 3600)


class IsEnvErrorTests(unittest.TestCase):
    """Q4 strict mode: require both traceback header AND terminating
    ModuleNotFoundError / ImportError line.  Bare keyword mentions must NOT
    trigger a rebuild."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.stderr_file = Path(self._tmp.name) / "stderr.txt"

    def _run(self, payload: str) -> int:
        self.stderr_file.write_text(payload, encoding="utf-8")
        return venv_lifecycle.main(
            ["is-env-error", "--stderr-file", str(self.stderr_file)]
        )

    def test_full_module_not_found_traceback_matches(self) -> None:
        payload = (
            "Traceback (most recent call last):\n"
            "  File \"build_index.py\", line 30, in <module>\n"
            "    import parse_evals\n"
            "ModuleNotFoundError: No module named 'parse_evals'\n"
        )
        self.assertEqual(self._run(payload), 0)

    def test_full_import_error_traceback_matches(self) -> None:
        payload = (
            "Traceback (most recent call last):\n"
            "  File \"foo.py\", line 1, in <module>\n"
            "    from bar import baz\n"
            "ImportError: cannot import name 'baz' from 'bar'\n"
        )
        self.assertEqual(self._run(payload), 0)

    def test_keyword_only_does_not_match(self) -> None:
        # No traceback header => not an env error.
        self.assertEqual(
            self._run("ModuleNotFoundError: No module named 'requests'\n"), 1
        )

    def test_traceback_with_unrelated_terminator_does_not_match(self) -> None:
        payload = (
            "Traceback (most recent call last):\n"
            "  File \"foo.py\", line 1, in <module>\n"
            "ValueError: bad input\n"
        )
        self.assertEqual(self._run(payload), 1)

    def test_log_message_mentioning_importerror_does_not_match(self) -> None:
        # A log line that quotes the word 'ImportError' inside prose must not
        # be misread as a traceback.
        self.assertEqual(
            self._run("INFO: handled ImportError gracefully\n"), 1
        )

    def test_unrelated_error(self) -> None:
        self.assertEqual(self._run("ValueError: bad input\n"), 1)

    def test_missing_file(self) -> None:
        result = venv_lifecycle.main(
            ["is-env-error", "--stderr-file", str(self.stderr_file.with_suffix(".missing"))]
        )
        self.assertEqual(result, 1)


class CleanupIfStaleTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.vd = venv_lifecycle.venv_dir(self.base)
        self.vd.mkdir()
        self.cfg = self.vd / "pyvenv.cfg"
        self.cfg.write_text("home = /usr\n", encoding="utf-8")

    def test_within_ttl_keeps_venv(self) -> None:
        rc = venv_lifecycle.main(
            ["cleanup-if-stale", "--base", str(self.base), "--plugin-root", ".",
             "--ttl-hours", "72"]
        )
        self.assertEqual(rc, 0)
        self.assertTrue(self.vd.exists())

    def test_beyond_ttl_removes_venv(self) -> None:
        old = time.time() - 100 * 3600
        os.utime(self.cfg, (old, old))
        rc = venv_lifecycle.main(
            ["cleanup-if-stale", "--base", str(self.base), "--plugin-root", ".",
             "--ttl-hours", "72"]
        )
        self.assertEqual(rc, 0)
        self.assertFalse(self.vd.exists())

    def test_missing_venv_is_noop(self) -> None:
        import shutil
        shutil.rmtree(self.vd)
        rc = venv_lifecycle.main(
            ["cleanup-if-stale", "--base", str(self.base), "--plugin-root", ".",
             "--ttl-hours", "72"]
        )
        self.assertEqual(rc, 0)


class EnsureWithoutDepsTests(unittest.TestCase):
    """When requirements.txt has no active deps, ensure must be a no-op."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        (self.plugin_root / "references" / "scripts" / "setup").mkdir(parents=True)
        (self.plugin_root / "references" / "scripts" / "setup" / "requirements.txt").write_text(
            "# stdlib only\n", encoding="utf-8"
        )

    def test_ensure_skips_when_no_deps(self) -> None:
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            rc = venv_lifecycle.main(
                ["ensure", "--base", str(self.base),
                 "--plugin-root", str(self.plugin_root)]
            )
        self.assertEqual(rc, 0)
        mocked.assert_not_called()
        self.assertFalse(venv_lifecycle.venv_dir(self.base).exists())


class EnsureWithDepsTests(unittest.TestCase):
    """When deps are listed and venv missing, ensure must call construct."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        (self.plugin_root / "references" / "scripts" / "setup").mkdir(parents=True)
        (self.plugin_root / "references" / "scripts" / "setup" / "requirements.txt").write_text(
            "requests\n", encoding="utf-8"
        )

    def test_ensure_constructs_when_missing(self) -> None:
        with mock.patch.object(venv_lifecycle, "construct", return_value=True) as mocked:
            rc = venv_lifecycle.main(
                ["ensure", "--base", str(self.base),
                 "--plugin-root", str(self.plugin_root)]
            )
        self.assertEqual(rc, 0)
        mocked.assert_called_once()

    def test_ensure_skips_when_python_already_present(self) -> None:
        # Pre-create what looks like a venv python.
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            rc = venv_lifecycle.main(
                ["ensure", "--base", str(self.base),
                 "--plugin-root", str(self.plugin_root)]
            )
        self.assertEqual(rc, 0)
        mocked.assert_not_called()


class RebuildBudgetTests(unittest.TestCase):
    """Q5 budget: rebuild is permitted up to REBUILD_LIMIT (3) times per
    session, tracked by an integer counter file.  session-reset clears it."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        (self.plugin_root / "references" / "scripts" / "setup").mkdir(parents=True)
        (self.plugin_root / "references" / "scripts" / "setup" / "requirements.txt").write_text(
            "requests\n", encoding="utf-8"
        )
        self.counter = self.base / venv_lifecycle.REBUILD_COUNT_FILE

    def _rebuild(self) -> int:
        return venv_lifecycle.main(
            ["rebuild", "--base", str(self.base),
             "--plugin-root", str(self.plugin_root)]
        )

    def test_first_rebuild_writes_count_one(self) -> None:
        with mock.patch.object(venv_lifecycle, "construct", return_value=True):
            rc = self._rebuild()
        self.assertEqual(rc, 0)
        self.assertEqual(self.counter.read_text(encoding="utf-8").strip(), "1")

    def test_three_rebuilds_succeed(self) -> None:
        with mock.patch.object(venv_lifecycle, "construct", return_value=True) as mocked:
            self.assertEqual(self._rebuild(), 0)
            self.assertEqual(self._rebuild(), 0)
            self.assertEqual(self._rebuild(), 0)
        self.assertEqual(mocked.call_count, 3)
        self.assertEqual(self.counter.read_text(encoding="utf-8").strip(), "3")

    def test_fourth_rebuild_short_circuits(self) -> None:
        self.base.mkdir(parents=True, exist_ok=True)
        self.counter.write_text("3", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            rc = self._rebuild()
        self.assertEqual(rc, 2)
        mocked.assert_not_called()
        # Counter must not advance past the limit.
        self.assertEqual(self.counter.read_text(encoding="utf-8").strip(), "3")

    def test_corrupt_counter_treated_as_zero(self) -> None:
        self.base.mkdir(parents=True, exist_ok=True)
        self.counter.write_text("not-a-number", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct", return_value=True):
            rc = self._rebuild()
        self.assertEqual(rc, 0)
        self.assertEqual(self.counter.read_text(encoding="utf-8").strip(), "1")

    def test_session_reset_removes_counter(self) -> None:
        self.base.mkdir(parents=True, exist_ok=True)
        self.counter.write_text("3", encoding="utf-8")
        rc = venv_lifecycle.main(
            ["session-reset", "--base", str(self.base), "--plugin-root", "."]
        )
        self.assertEqual(rc, 0)
        self.assertFalse(self.counter.exists())

    def test_session_reset_when_counter_missing(self) -> None:
        rc = venv_lifecycle.main(
            ["session-reset", "--base", str(self.base), "--plugin-root", "."]
        )
        self.assertEqual(rc, 0)


class PythonBinTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        (self.plugin_root / "references" / "scripts" / "setup").mkdir(parents=True)

    def _run(self, no_construct: bool = False) -> tuple[int, str]:
        from io import StringIO
        argv = ["python-bin", "--base", str(self.base),
                "--plugin-root", str(self.plugin_root)]
        if no_construct:
            argv.append("--no-construct")
        buf = StringIO()
        with mock.patch.object(sys, "stdout", buf):
            rc = venv_lifecycle.main(argv)
        return rc, buf.getvalue().strip()

    def test_no_deps_returns_system_python(self) -> None:
        (self.plugin_root / "references" / "scripts" / "setup"
         / "requirements.txt").write_text("# stdlib only\n", encoding="utf-8")
        rc, out = self._run()
        self.assertEqual(rc, 0)
        self.assertTrue(Path(out).name.lower().startswith("python"))

    def test_deps_with_existing_venv_returns_venv_python(self) -> None:
        (self.plugin_root / "references" / "scripts" / "setup"
         / "requirements.txt").write_text("requests\n", encoding="utf-8")
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        rc, out = self._run()
        self.assertEqual(rc, 0)
        self.assertEqual(Path(out), py)

    def test_no_construct_falls_back_to_system_when_venv_absent(self) -> None:
        (self.plugin_root / "references" / "scripts" / "setup"
         / "requirements.txt").write_text("requests\n", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            rc, out = self._run(no_construct=True)
        self.assertEqual(rc, 0)
        mocked.assert_not_called()
        # Should have fallen back to a system python path.
        self.assertNotEqual(Path(out), venv_lifecycle.venv_python(self.base))


if __name__ == "__main__":
    unittest.main()
