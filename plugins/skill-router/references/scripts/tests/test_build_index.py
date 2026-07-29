"""Unit tests for ``build_index`` helpers.

Run from the repository root with the standard library only::

    python -m unittest plugins/skill-router/references/scripts/tests/test_build_index.py
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

_LIB = Path(__file__).resolve().parent.parent / "routing"
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
        # ``_resolve_install_path`` calls ``Path.resolve(strict=True)`` which
        # canonicalises Windows 8.3 short paths (e.g. ``SOMEUSR~1``) into their
        # long-name form.  Mirror that here so equality assertions hold on
        # any Windows runner regardless of the user profile name length.
        self.real_dir = Path(self._tmp.name).resolve()

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


class BuildEntryPointSmokeTests(unittest.TestCase):
    """End-to-end coverage for the v0.4 build() with embedding disabled.

    ``embedding.enabled = false`` (the default) is the existing-user
    code path; if it ever started touching the LLM/embedding stack the
    on-disk index would gain unintended fields.  This test pins the
    output schema (SCHEMA_VERSION = 3, ``stats.embedding`` present).
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.addCleanup(self._close_log_handlers)
        self.base = Path(self._tmp.name)
        self._patch_base = mock.patch.object(
            build_index, "resolve_base_dir", return_value=self.base
        )
        self._patch_base.start()
        self.addCleanup(self._patch_base.stop)
        self._patch_read = mock.patch.object(
            build_index, "_read_json", return_value=None
        )
        self._patch_read.start()
        self.addCleanup(self._patch_read.stop)

    @staticmethod
    def _close_log_handlers() -> None:
        import logging as _logging

        for name in ("skill_router.build_index", "skill_router.embedding"):
            lg = _logging.getLogger(name)
            for handler in list(lg.handlers):
                try:
                    handler.close()
                except Exception:
                    pass
                lg.removeHandler(handler)

    def test_build_emits_schema_v3_and_stats_embedding_disabled(self) -> None:
        index = build_index.build()
        self.assertEqual(index["schema_version"], 3)
        self.assertIn("embedding", index["stats"])
        self.assertFalse(index["stats"]["embedding"]["enabled"])
        self.assertEqual(index["stats"]["embedding"]["skills_vectorised"], 0)
        self.assertEqual(index["skills"], [])
        self.assertTrue((self.base / "index.json").is_file())
        on_disk = json.loads((self.base / "index.json").read_text(encoding="utf-8"))
        self.assertEqual(on_disk["schema_version"], 3)
        self.assertFalse(on_disk["stats"]["embedding"]["enabled"])

    def test_error_log_does_not_follow_a_symlink(self) -> None:
        """例外経路の error.log がリンクを追従しないこと。

        `<base>` はリポジトリ配下に解決されうる。index.json をディレクトリとして
        同梱すれば `_atomic_write` が失敗し、この経路に確実に到達できる。
        追記先をリンクで奪われると traceback を任意ファイルへ書き込まれる。
        """
        outside = Path(self._tmp.name) / "outside.txt"
        outside.write_text("keep me", encoding="utf-8")
        try:
            os.symlink(outside, self.base / "error.log")
        except (OSError, NotImplementedError, AttributeError):
            self.skipTest("symlink creation not permitted")
        # index.json をディレクトリ化して os.replace を失敗させる
        (self.base / "index.json").mkdir(parents=True, exist_ok=True)
        self.assertEqual(build_index.main(), 0)  # フェイルオープン
        self.assertEqual(outside.read_text(encoding="utf-8"), "keep me")
        self.assertFalse((self.base / "error.log").is_symlink())

    def test_unwritable_index_keeps_the_previous_one(self) -> None:
        """`index.json` をディレクトリとして同梱されても例外を外へ出さない。

        `_atomic_write` の OSError が `build()` の外へ抜けると、索引が更新
        されないだけのはずが例外経路に落ちる。前回の索引を据え置いて
        フェイルオープンする。
        """
        (self.base / "index.json").mkdir(parents=True, exist_ok=True)
        index = build_index.build()  # 例外を送出しないこと
        self.assertEqual(index["schema_version"], 3)
        self.assertEqual(build_index.main(), 0)

    def test_installed_plugins_accepts_the_path_key(self) -> None:
        """`installPath` ではなく `path` を持つスキーマも受けること。"""
        import installed
        (self.base / "installed_plugins.json").write_text(
            json.dumps({"version": 2, "plugins": {
                "p@mkt": [{"path": str(self.base)}]}}), encoding="utf-8")
        catalogue = installed.installed_plugins(self.base)
        self.assertIn("p", catalogue)
        self.assertTrue(catalogue["p"])

    def test_max_postings_per_keyword_is_honoured(self) -> None:
        """テンプレートが配るキーが実際に索引構築へ効くこと。

        以前は `MAX_POSTINGS_PER_KEYWORD` 定数だけが使われており、利用者が
        config.json を編集しても何も起きなかった（診断ケースはこのキーの
        調整を対処方針として提示している）。
        """
        skills = [{"qualified_name": f"p:s{i}", "keywords": ["shared"],
                   "trigger_phrases": []} for i in range(4)]
        wide = build_index.build_inverted_index(skills, max_postings=10)
        self.assertIn("shared", wide["index"])
        narrow = build_index.build_inverted_index(skills, max_postings=3)
        self.assertNotIn("shared", narrow["index"])
        self.assertIn("shared", narrow["overgeneric"])

    def test_max_postings_is_read_from_config_and_clamped(self) -> None:
        """リポジトリ供給の値でも壊れない範囲に収めること。"""
        cfg = self.base / "config.json"
        cfg.write_text(json.dumps(
            {"candidate_filter": {"max_postings_per_keyword": 7}}),
            encoding="utf-8")
        self.assertEqual(build_index.resolve_max_postings(self.base), 7)

        # `1e400` は JSON パースで float('inf') になり、int() が OverflowError を
        # 送出する。捕捉しないと当該リポジトリで索引構築が毎回失敗する。
        for bad, expected in ((0, 1), (-5, 1), (10 ** 9, 500), ("x", 50),
                              (float("inf"), 50), (float("nan"), 50)):
            cfg.write_text(json.dumps(
                {"candidate_filter": {"max_postings_per_keyword": bad}}),
                encoding="utf-8")
            with self.subTest(value=bad):
                self.assertEqual(
                    build_index.resolve_max_postings(self.base), expected)

    def test_embedding_stack_is_not_imported_when_disabled(self) -> None:
        """既定（opt-out）で numpy / fastembed を引き込まないこと。

        route.py が build_index を import するため、ここでモジュール先頭に
        置くとプロンプト経路にまで import 費用が乗る。無効時にモジュール
        グローバルが未束縛のままであることを不変条件として固定する。
        """
        build_index.embedding_client = None
        build_index.embedding_enrich = None
        build_index.build()
        self.assertIsNone(build_index.embedding_client)
        self.assertIsNone(build_index.embedding_enrich)

    def test_build_passes_user_config_into_embedding_pipeline(self) -> None:
        # The embedding block is owned by <venv-base>, not <base>, so patch
        # that reader.  ensure_skill_vectors is patched to assert it was
        # called with enabled=True and the supplied model name.
        # 埋め込みモジュールは遅延ロードなので、patch する前に束縛しておく。
        self.assertTrue(build_index._load_embedding_stack())
        with mock.patch.object(
            build_index.config_io,
            "embedding_section",
            return_value={"enabled": True, "model": "BAAI/bge-small-en-v1.5"},
        ), mock.patch.object(
            build_index.embedding_enrich,
            "ensure_skill_vectors",
            return_value=({}, None),
        ) as ensure:
            build_index.build()
        self.assertEqual(ensure.call_count, 1)
        cfg = ensure.call_args[0][2]
        self.assertTrue(cfg.enabled)
        self.assertEqual(cfg.model, "BAAI/bge-small-en-v1.5")


if __name__ == "__main__":
    unittest.main()
