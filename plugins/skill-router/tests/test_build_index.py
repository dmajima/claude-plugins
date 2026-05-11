"""Unit tests for ``build_index`` helpers.

Run from the repository root with the standard library only::

    python -m unittest plugins/skill-router/tests/test_build_index.py
"""
from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

_LIB = (
    Path(__file__).resolve().parent.parent
    / "references"
    / "scripts"
    / "lib"
)
sys.path.insert(0, str(_LIB))

import build_index  # noqa: E402  (path adjusted above)


class IsoToEpochTests(unittest.TestCase):
    def test_z_and_offset_yield_same_instant(self) -> None:
        z = build_index._iso8601_to_epoch("2026-05-02T14:58:50Z")
        offset = build_index._iso8601_to_epoch("2026-05-02T23:58:50+09:00")
        self.assertEqual(z, offset)
        self.assertGreater(z, 0)

    def test_milliseconds_accepted(self) -> None:
        self.assertGreater(
            build_index._iso8601_to_epoch("2026-05-02T14:58:50.043Z"),
            0,
        )

    def test_empty_returns_zero(self) -> None:
        self.assertEqual(build_index._iso8601_to_epoch(""), 0)

    def test_none_returns_zero(self) -> None:
        self.assertEqual(build_index._iso8601_to_epoch(None), 0)

    def test_garbage_returns_zero(self) -> None:
        self.assertEqual(build_index._iso8601_to_epoch("not-a-timestamp"), 0)


class EntryScoreTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.real_dir = self._tmp.name

    def test_scope_match_outranks_recency(self) -> None:
        old_match = {
            "scope": "user",
            "installPath": self.real_dir,
            "lastUpdated": "2020-01-01T00:00:00Z",
        }
        new_mismatch = {
            "scope": "project",
            "installPath": self.real_dir,
            "lastUpdated": "2030-01-01T00:00:00Z",
        }
        self.assertGreater(
            build_index._entry_score(old_match, "user"),
            build_index._entry_score(new_mismatch, "user"),
        )

    def test_path_existence_outranks_recency(self) -> None:
        new_missing = {
            "installPath": "/definitely/does/not/exist",
            "lastUpdated": "2030-01-01T00:00:00Z",
        }
        old_existing = {
            "installPath": self.real_dir,
            "lastUpdated": "2020-01-01T00:00:00Z",
        }
        self.assertGreater(
            build_index._entry_score(old_existing, None),
            build_index._entry_score(new_missing, None),
        )

    def test_recency_picks_latest_when_other_factors_tie(self) -> None:
        older = {"installPath": self.real_dir, "lastUpdated": "2020-01-01T00:00:00Z"}
        newer = {"installPath": self.real_dir, "lastUpdated": "2030-01-01T00:00:00Z"}
        self.assertGreater(
            build_index._entry_score(newer, None),
            build_index._entry_score(older, None),
        )

    def test_installed_at_used_when_last_updated_missing(self) -> None:
        with_installed = {"installPath": self.real_dir, "installedAt": "2030-01-01T00:00:00Z"}
        without_anything = {"installPath": self.real_dir}
        self.assertGreater(
            build_index._entry_score(with_installed, None),
            build_index._entry_score(without_anything, None),
        )

    def test_install_path_breaks_ties_deterministically(self) -> None:
        a = {"installPath": "/path/a"}
        b = {"installPath": "/path/b"}
        self.assertGreater(
            build_index._entry_score(b, None),
            build_index._entry_score(a, None),
        )


class ResolveInstallPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.real_dir = Path(self._tmp.name)

    def _v2(self, entries):
        return {"version": 2, "plugins": {"foo@bar": entries}}

    def test_list_picks_highest_score(self) -> None:
        old = {
            "scope": "user",
            "installPath": str(self.real_dir),
            "lastUpdated": "2020-01-01T00:00:00Z",
        }
        new = {
            "scope": "user",
            "installPath": str(self.real_dir),
            "lastUpdated": "2030-01-01T00:00:00Z",
        }
        self.assertEqual(
            build_index._resolve_install_path(
                self._v2([old, new]), "foo@bar", expected_scope="user"
            ),
            self.real_dir,
        )

    def test_list_prefers_scope_match_over_recency(self) -> None:
        good = self.real_dir / "right"
        good.mkdir()
        bogus = self.real_dir / "wrong"
        bogus.mkdir()
        new_mismatch = {
            "scope": "project",
            "installPath": str(bogus),
            "lastUpdated": "2030-01-01T00:00:00Z",
        }
        old_match = {
            "scope": "user",
            "installPath": str(good),
            "lastUpdated": "2020-01-01T00:00:00Z",
        }
        self.assertEqual(
            build_index._resolve_install_path(
                self._v2([new_mismatch, old_match]), "foo@bar", expected_scope="user"
            ),
            good,
        )

    def test_empty_list_returns_none(self) -> None:
        self.assertIsNone(
            build_index._resolve_install_path(self._v2([]), "foo@bar")
        )

    def test_list_with_only_non_dicts_returns_none(self) -> None:
        self.assertIsNone(
            build_index._resolve_install_path(
                self._v2(["garbage", 42, None]), "foo@bar"
            )
        )

    def test_list_with_mixed_types_picks_dict(self) -> None:
        valid = {"installPath": str(self.real_dir), "lastUpdated": "2026-01-01T00:00:00Z"}
        self.assertEqual(
            build_index._resolve_install_path(
                self._v2([valid, "garbage", None]), "foo@bar"
            ),
            self.real_dir,
        )

    def test_dict_form_backward_compat(self) -> None:
        installed = {
            "version": 1,
            "plugins": {"foo@bar": {"installPath": str(self.real_dir)}},
        }
        self.assertEqual(
            build_index._resolve_install_path(installed, "foo@bar"),
            self.real_dir,
        )

    def test_install_path_not_directory_returns_none(self) -> None:
        self.assertIsNone(
            build_index._resolve_install_path(
                self._v2(
                    [{"installPath": "/no/such/path", "lastUpdated": "2026-01-01T00:00:00Z"}]
                ),
                "foo@bar",
            )
        )

    def test_install_path_field_missing_returns_none(self) -> None:
        self.assertIsNone(
            build_index._resolve_install_path(
                self._v2([{"lastUpdated": "2026-01-01T00:00:00Z"}]), "foo@bar"
            )
        )

    def test_no_timestamps_does_not_crash(self) -> None:
        # Both entries lack timestamps; recency degenerates to 0 and the
        # installPath tiebreaker decides.  We just assert it returns a
        # valid Path without raising.
        a = self.real_dir / "a"
        a.mkdir()
        b = self.real_dir / "b"
        b.mkdir()
        result = build_index._resolve_install_path(
            self._v2([{"installPath": str(a)}, {"installPath": str(b)}]),
            "foo@bar",
        )
        self.assertIn(result, {a, b})


if __name__ == "__main__":
    unittest.main()
