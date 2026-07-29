"""Unit tests for venv_lifecycle.

Run from the repository root::

    python -m unittest plugins/skill-router/references/scripts/tests/test_venv_lifecycle.py
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

_LIB = Path(__file__).resolve().parent.parent / "routing"
sys.path.insert(0, str(_LIB))

import venv_lifecycle  # noqa: E402

_PLUGIN_ROOT = Path(__file__).resolve().parents[3]


def _write_config(base: Path, payload: dict) -> None:
    base.mkdir(parents=True, exist_ok=True)
    (base / "config.json").write_text(json.dumps(payload), encoding="utf-8")


def _enable_embedding(base: Path) -> None:
    _write_config(base, {"embedding": {"enabled": True}})


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


class EmbeddingGateTests(unittest.TestCase):
    """A venv is built only when the user opted into embedding routing."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.req = Path(self._tmp.name) / "requirements.txt"
        self.req.write_text("fastembed>=0.3\n", encoding="utf-8")

    def test_missing_config_is_disabled(self) -> None:
        self.assertFalse(venv_lifecycle.embedding_enabled(self.base))
        self.assertFalse(venv_lifecycle.venv_required(self.base, self.req))

    def test_explicit_false_is_disabled(self) -> None:
        _write_config(self.base, {"embedding": {"enabled": False}})
        self.assertFalse(venv_lifecycle.venv_required(self.base, self.req))

    def test_enabled_requires_active_requirements(self) -> None:
        _enable_embedding(self.base)
        self.assertTrue(venv_lifecycle.venv_required(self.base, self.req))
        empty = Path(self._tmp.name) / "empty.txt"
        empty.write_text("# stdlib only\n", encoding="utf-8")
        self.assertFalse(venv_lifecycle.venv_required(self.base, empty))

    def test_malformed_config_is_disabled(self) -> None:
        self.base.mkdir(parents=True, exist_ok=True)
        (self.base / "config.json").write_text("{broken", encoding="utf-8")
        self.assertFalse(venv_lifecycle.venv_required(self.base, self.req))

    def test_ttl_hours_configurable(self) -> None:
        self.assertEqual(venv_lifecycle.configured_ttl_hours(self.base), 168.0)
        _write_config(self.base, {"venv": {"ttl_hours": 24}})
        self.assertEqual(venv_lifecycle.configured_ttl_hours(self.base), 24.0)

    def test_non_positive_ttl_falls_back_to_default(self) -> None:
        _write_config(self.base, {"venv": {"ttl_hours": 0}})
        self.assertEqual(venv_lifecycle.configured_ttl_hours(self.base), 168.0)

    def test_sub_hour_ttl_is_raised_to_the_floor(self) -> None:
        """0 < value < 1h は下限（1 時間）へ引き上げること。

        `<venv-base>/config.json` は `${CLAUDE_PLUGIN_DATA}` 経由で外部から
        与えられうる。0.0001 のような値をそのまま使うと、セッションごとに
        撤去 → 再構築（最大 240 秒の pip install）を繰り返す。
        """
        for value in (0.0001, 0.5, 0.999):
            _write_config(self.base, {"venv": {"ttl_hours": value}})
            with self.subTest(value=value):
                self.assertEqual(
                    venv_lifecycle.configured_ttl_hours(self.base),
                    float(venv_lifecycle.VENV_TTL_HOURS_MIN))

    def test_ttl_at_the_floor_is_kept(self) -> None:
        _write_config(self.base, {"venv": {"ttl_hours": 1}})
        self.assertEqual(venv_lifecycle.configured_ttl_hours(self.base), 1.0)

    def test_malformed_ttl_falls_back_to_default(self) -> None:
        for bad in ("abc", None, [], {"x": 1}):
            _write_config(self.base, {"venv": {"ttl_hours": bad}})
            with self.subTest(value=bad):
                self.assertEqual(
                    venv_lifecycle.configured_ttl_hours(self.base), 168.0)


class VenvBaseResolutionTests(unittest.TestCase):
    """The venv must never resolve into a repository-relative directory."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)

    def test_plugin_data_wins(self) -> None:
        target = Path(self._tmp.name) / "plugin-data"
        with mock.patch.dict(os.environ, {"CLAUDE_PLUGIN_DATA": str(target)}):
            self.assertEqual(venv_lifecycle.resolve_venv_base(), target)

    def test_falls_back_to_home_not_repository(self) -> None:
        repo = Path(self._tmp.name) / "repo"
        (repo / ".git").mkdir(parents=True)
        env = {k: v for k, v in os.environ.items()
               if k not in ("CLAUDE_PLUGIN_DATA",)}
        env["CLAUDE_PROJECT_DIR"] = str(repo)
        with mock.patch.dict(os.environ, env, clear=True):
            resolved = venv_lifecycle.resolve_venv_base()
        self.assertNotIn(str(repo), str(resolved))
        self.assertEqual(resolved.parts[-3:],
                         (".local", "plugins", "skill-router"))


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


class CleanupIfStaleTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.vd = venv_lifecycle.venv_dir(self.base)
        self.vd.mkdir()
        self.cfg = self.vd / "pyvenv.cfg"
        self.cfg.write_text("home = /usr\n", encoding="utf-8")
        # TTL 判定そのものを見るケース群なので、venv が「必要とされている」
        # 状態（依存あり + 埋め込み有効）を既定にする。opt-out 時の回収は
        # test_optout_removes_venv_regardless_of_ttl で別に検証する。
        self.plugin_root = Path(self._tmp.name) / "plugin"
        setup_dir = self.plugin_root / "references" / "scripts" / "setup"
        setup_dir.mkdir(parents=True)
        (setup_dir / "requirements.txt").write_text(
            "fastembed>=0.3\n", encoding="utf-8")
        _enable_embedding(self.base)

    def _cleanup(self, *extra: str) -> int:
        return venv_lifecycle.main(
            ["cleanup-if-stale", "--base", str(self.base),
             "--plugin-root", str(self.plugin_root)] + list(extra)
        )

    def test_optout_removes_venv_regardless_of_ttl(self) -> None:
        """埋め込みを無効に戻したら TTL によらず回収すること。

        opt-out 後は venv に到達する経路が無くなるため、保持しても
        約 650 MB が無駄に残るだけになる。
        """
        _write_config(self.base, {"embedding": {"enabled": False}})
        venv_lifecycle.touch_last_used(self.base)  # 直前まで使っていても
        self.assertEqual(self._cleanup(), 0)
        self.assertFalse(self.vd.exists())

    def test_no_active_requirements_removes_venv(self) -> None:
        """依存が空になった場合も同様に回収すること。"""
        (self.plugin_root / "references" / "scripts" / "setup"
         / "requirements.txt").write_text("# stdlib only\n", encoding="utf-8")
        venv_lifecycle.touch_last_used(self.base)
        self.assertEqual(self._cleanup(), 0)
        self.assertFalse(self.vd.exists())

    def test_default_ttl_is_seven_days(self) -> None:
        self.assertEqual(venv_lifecycle.VENV_TTL_HOURS_DEFAULT, 168)

    def test_within_ttl_keeps_venv(self) -> None:
        venv_lifecycle.touch_last_used(self.base)
        self.assertEqual(self._cleanup("--ttl-hours", "72"), 0)
        self.assertTrue(self.vd.exists())

    def test_recent_use_keeps_old_venv(self) -> None:
        """構築が古くても最近使われていれば撤去されないこと（本修正の主眼）。"""
        old = time.time() - 1000 * 3600      # pyvenv.cfg は 1000 h 前
        os.utime(self.cfg, (old, old))
        venv_lifecycle.touch_last_used(self.base)   # 最終利用は今
        self.assertEqual(self._cleanup(), 0)
        self.assertTrue(self.vd.exists())

    def _backdate(self, seconds: float) -> None:
        """構築時刻と最終利用時刻の両方を遡らせる（実運用のアイドル状態）。"""
        venv_lifecycle.touch_last_used(self.base)
        old = time.time() - seconds
        os.utime(venv_lifecycle.venv_last_used_path(self.base), (old, old))
        os.utime(self.cfg, (old, old))

    def test_idle_beyond_ttl_removes_venv(self) -> None:
        """最終利用から TTL 超過なら撤去されること。"""
        self._backdate(192 * 3600)  # 8 days idle
        self.assertEqual(self._cleanup(), 0)
        self.assertFalse(self.vd.exists())

    def test_configured_ttl_is_honoured(self) -> None:
        _write_config(self.base, {"venv": {"ttl_hours": 1}})
        self._backdate(2 * 3600)
        self.assertEqual(self._cleanup(), 0)
        self.assertFalse(self.vd.exists())

    def test_backdated_marker_alone_does_not_remove_fresh_venv(self) -> None:
        """マーカーだけを過去にしても、構築が新しければ撤去しないこと。

        マーカーは平文の mtime なので、改竄・バックアップ復元・時刻ずれで
        過去日付になりうる。それだけで teardown + 再インストールが誘発され
        ないよう、構築時刻と突き合わせる。
        """
        venv_lifecycle.touch_last_used(self.base)
        marker = venv_lifecycle.venv_last_used_path(self.base)
        old = time.time() - 500 * 3600
        os.utime(marker, (old, old))   # pyvenv.cfg は setUp のまま（新しい）
        self.assertEqual(self._cleanup(), 0)
        self.assertTrue(self.vd.exists())

    def test_marker_absent_adopts_existing_venv(self) -> None:
        """マーカー不在の既存 venv は撤去せず採用すること（移行時の強制再構築回避）。"""
        old = time.time() - 1000 * 3600
        os.utime(self.cfg, (old, old))
        self.assertFalse(venv_lifecycle.venv_last_used_path(self.base).exists())
        self.assertEqual(self._cleanup(), 0)
        self.assertTrue(self.vd.exists())
        self.assertTrue(venv_lifecycle.venv_last_used_path(self.base).exists())

    def test_unknown_provenance_venv_is_removed(self) -> None:
        """マーカーも pyvenv.cfg も無いディレクトリは由来不明として撤去すること。"""
        self.cfg.unlink()
        (self.vd / "Scripts").mkdir()
        self.assertEqual(venv_lifecycle.venv_idle_seconds(self.base),
                         float("inf"))
        self.assertEqual(self._cleanup(), 0)
        self.assertFalse(self.vd.exists())

    def test_future_marker_is_rewritten_not_trusted(self) -> None:
        """未来 mtime のマーカーは信頼せず作り直すこと。"""
        venv_lifecycle.touch_last_used(self.base)
        marker = venv_lifecycle.venv_last_used_path(self.base)
        future = time.time() + 10 * 24 * 3600
        os.utime(marker, (future, future))
        idle = venv_lifecycle.venv_idle_seconds(self.base)
        self.assertEqual(idle, 0.0)
        self.assertLess(abs(marker.stat().st_mtime - time.time()), 60)

    def test_missing_venv_is_noop(self) -> None:
        shutil.rmtree(self.vd)
        self.assertEqual(self._cleanup("--ttl-hours", "72"), 0)

    def test_teardown_removes_marker(self) -> None:
        """teardown でマーカーも消えること（再構築直後の誤失効を防ぐ）。"""
        venv_lifecycle.touch_last_used(self.base)
        marker = venv_lifecycle.venv_last_used_path(self.base)
        self.assertTrue(marker.exists())
        self.assertTrue(venv_lifecycle.teardown(self.base))
        self.assertFalse(marker.exists())

    def test_teardown_reports_failure(self) -> None:
        """撤去に失敗したら False を返すこと（残骸の上に構築させない）。"""
        with mock.patch.object(venv_lifecycle.shutil, "rmtree",
                               side_effect=OSError("locked")):
            self.assertFalse(venv_lifecycle.teardown(self.base))
        self.assertTrue(self.vd.exists())


class EnsureTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        setup_dir = self.plugin_root / "references" / "scripts" / "setup"
        setup_dir.mkdir(parents=True)
        self.req = setup_dir / "requirements.txt"
        self.req.write_text("fastembed>=0.3\n", encoding="utf-8")

    def _ensure(self) -> int:
        return venv_lifecycle.main(
            ["ensure", "--base", str(self.base),
             "--plugin-root", str(self.plugin_root)]
        )

    def test_skips_when_no_deps(self) -> None:
        self.req.write_text("# stdlib only\n", encoding="utf-8")
        _enable_embedding(self.base)
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_not_called()

    def test_skips_when_embedding_disabled(self) -> None:
        """既定（embedding 無効）では構築しないこと。"""
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_not_called()
        self.assertFalse(venv_lifecycle.venv_dir(self.base).exists())

    def test_constructs_when_enabled_and_missing(self) -> None:
        _enable_embedding(self.base)
        with mock.patch.object(venv_lifecycle, "construct",
                               return_value=True) as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_called_once()

    def test_skips_when_ready_marker_matches(self) -> None:
        _enable_embedding(self.base)
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        (venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg").write_text(
            "home = /usr\n", encoding="utf-8")
        venv_lifecycle.venv_ready_path(self.base).write_text(
            venv_lifecycle._requirements_fingerprint(self.req), encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_not_called()

    def test_rebuilds_when_ready_marker_missing(self) -> None:
        """pip 完了前に中断された venv を「構築済み」と誤認しないこと。"""
        _enable_embedding(self.base)
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        (venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg").write_text(
            "home = /usr\n", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct",
                               return_value=True) as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_called_once()

    def test_rebuilds_when_requirements_changed(self) -> None:
        """依存定義が変わったら作り直すこと。"""
        _enable_embedding(self.base)
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        (venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg").write_text(
            "home = /usr\n", encoding="utf-8")
        venv_lifecycle.venv_ready_path(self.base).write_text(
            "stale-fingerprint", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct",
                               return_value=True) as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_called_once()

    def test_rebuilds_when_pyvenv_cfg_missing(self) -> None:
        """python はあるが pyvenv.cfg が無い残骸は健全とみなさないこと。"""
        _enable_embedding(self.base)
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct",
                               return_value=True) as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_called_once()

    def test_backoff_blocks_repeated_failures(self) -> None:
        _enable_embedding(self.base)
        venv_lifecycle._write_failure_state(
            self.base, venv_lifecycle.CONSTRUCT_FAILURE_LIMIT)
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_not_called()

    def test_backoff_expires(self) -> None:
        _enable_embedding(self.base)
        self.base.mkdir(parents=True, exist_ok=True)
        stale = time.time() - (venv_lifecycle.CONSTRUCT_BACKOFF_HOURS + 1) * 3600
        (self.base / venv_lifecycle.FAILURE_STATE_FILE).write_text(
            json.dumps({"count": 9, "last_attempt": stale}), encoding="utf-8")
        with mock.patch.object(venv_lifecycle, "construct",
                               return_value=True) as mocked:
            self.assertEqual(self._ensure(), 0)
        mocked.assert_called_once()


class RebuildBudgetTests(unittest.TestCase):
    """Q5 budget: rebuild is permitted up to REBUILD_LIMIT (3) times per
    session, tracked by an integer counter file.  session-reset clears it."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.plugin_root = Path(self._tmp.name) / "plugin"
        setup_dir = self.plugin_root / "references" / "scripts" / "setup"
        setup_dir.mkdir(parents=True)
        (setup_dir / "requirements.txt").write_text(
            "fastembed>=0.3\n", encoding="utf-8")
        _enable_embedding(self.base)
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

    def _req(self, body: str) -> None:
        (self.plugin_root / "references" / "scripts" / "setup"
         / "requirements.txt").write_text(body, encoding="utf-8")

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

    def _make_fake_venv(self) -> Path:
        py = venv_lifecycle.venv_python(self.base)
        py.parent.mkdir(parents=True, exist_ok=True)
        py.write_text("#!/bin/sh\n", encoding="utf-8")
        (venv_lifecycle.venv_dir(self.base) / "pyvenv.cfg").write_text(
            "home = /usr\n", encoding="utf-8")
        req = (self.plugin_root / "references" / "scripts" / "setup"
               / "requirements.txt")
        venv_lifecycle.venv_ready_path(self.base).write_text(
            venv_lifecycle._requirements_fingerprint(req), encoding="utf-8")
        return py

    def test_no_deps_returns_system_python(self) -> None:
        self._req("# stdlib only\n")
        rc, out = self._run()
        self.assertEqual(rc, 0)
        self.assertTrue(Path(out).name.lower().startswith("python"))

    def test_embedding_disabled_returns_system_python(self) -> None:
        """埋め込み無効なら venv があってもシステム Python を返すこと。"""
        self._req("fastembed>=0.3\n")
        py = self._make_fake_venv()
        rc, out = self._run()
        self.assertEqual(rc, 0)
        self.assertNotEqual(Path(out), py)

    def test_enabled_with_existing_venv_returns_venv_python(self) -> None:
        self._req("fastembed>=0.3\n")
        _enable_embedding(self.base)
        py = self._make_fake_venv()
        rc, out = self._run()
        self.assertEqual(rc, 0)
        self.assertEqual(Path(out), py)

    def test_no_construct_falls_back_to_system_when_venv_absent(self) -> None:
        self._req("fastembed>=0.3\n")
        _enable_embedding(self.base)
        with mock.patch.object(venv_lifecycle, "construct") as mocked:
            rc, out = self._run(no_construct=True)
        self.assertEqual(rc, 0)
        mocked.assert_not_called()
        self.assertNotEqual(Path(out), venv_lifecycle.venv_python(self.base))

    def test_python_bin_has_no_side_effects(self) -> None:
        """python-bin は純粋な問い合わせであること（順序依存を作らない）。"""
        self._req("fastembed>=0.3\n")
        _enable_embedding(self.base)
        self._make_fake_venv()
        marker = venv_lifecycle.venv_last_used_path(self.base)
        self.assertFalse(marker.exists())
        rc, _ = self._run()
        self.assertEqual(rc, 0)
        self.assertFalse(marker.exists())


class LastUsedMarkerTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"

    def test_touch_creates_marker(self) -> None:
        marker = venv_lifecycle.venv_last_used_path(self.base)
        self.assertFalse(marker.exists())
        venv_lifecycle.touch_last_used(self.base)
        self.assertTrue(marker.exists())

    def test_cli_touch_last_used(self) -> None:
        rc = venv_lifecycle.main(
            ["touch-last-used", "--base", str(self.base), "--plugin-root", "."]
        )
        self.assertEqual(rc, 0)
        self.assertTrue(venv_lifecycle.venv_last_used_path(self.base).exists())

    def test_touch_refreshes_existing_marker_without_rewriting_body(self) -> None:
        """既存マーカーは mtime のみ更新し、書き込みを行わないこと。"""
        venv_lifecycle.touch_last_used(self.base)
        marker = venv_lifecycle.venv_last_used_path(self.base)
        old = time.time() - 100 * 3600
        os.utime(marker, (old, old))

        with mock.patch.object(venv_lifecycle.os, "open") as opened:
            venv_lifecycle.touch_last_used(self.base)
        opened.assert_not_called()
        self.assertLess(time.time() - marker.stat().st_mtime, 60)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unsupported")
    def test_symlinked_marker_is_replaced_not_followed(self) -> None:
        """マーカーがシンボリックリンクなら追従せず置き換えること。"""
        outside = Path(self._tmp.name) / "outside.txt"
        outside.write_text("keep me\n", encoding="utf-8")
        original_mtime = time.time() - 5000
        os.utime(outside, (original_mtime, original_mtime))
        self.base.mkdir(parents=True, exist_ok=True)
        marker = venv_lifecycle.venv_last_used_path(self.base)
        try:
            os.symlink(outside, marker)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")

        venv_lifecycle.touch_last_used(self.base)

        self.assertFalse(marker.is_symlink())
        self.assertEqual(outside.read_text(encoding="utf-8"), "keep me\n")
        self.assertLess(abs(outside.stat().st_mtime - original_mtime), 5)

    def test_touch_if_active_is_noop_outside_venv(self) -> None:
        """システム Python で動作中はマーカーを作らないこと。"""
        with mock.patch.object(venv_lifecycle, "touch_last_used") as mocked:
            with mock.patch.object(sys, "prefix", sys.base_prefix):
                venv_lifecycle.touch_last_used_if_active()
        mocked.assert_not_called()

    def test_touch_if_active_updates_when_inside_venv(self) -> None:
        """venv 内 Python で動作中はその venv のマーカーを更新すること。"""
        vd = venv_lifecycle.venv_dir(self.base)
        vd.mkdir(parents=True)
        with mock.patch.object(sys, "prefix", str(vd)):
            with mock.patch.object(sys, "base_prefix", str(Path(self._tmp.name) / "sys")):
                venv_lifecycle.touch_last_used_if_active()
        self.assertTrue(venv_lifecycle.venv_last_used_path(self.base).exists())


class ConstructGuardTests(unittest.TestCase):
    """construct() must never build on top of a directory it failed to remove."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "data"
        self.req = Path(self._tmp.name) / "requirements.txt"
        self.req.write_text("fastembed>=0.3\n", encoding="utf-8")
        venv_lifecycle.venv_dir(self.base).mkdir(parents=True)

    def test_construct_aborts_when_teardown_fails(self) -> None:
        with mock.patch.object(venv_lifecycle, "_teardown_unlocked",
                               return_value=False):
            with mock.patch.object(venv_lifecycle.subprocess, "run") as ran:
                self.assertFalse(
                    venv_lifecycle.construct(self.base, self.req))
        ran.assert_not_called()

    def test_lock_blocks_concurrent_construct(self) -> None:
        fd = venv_lifecycle._acquire_lock(self.base)
        self.addCleanup(venv_lifecycle._release_lock, self.base, fd)
        self.assertIsNotNone(fd)
        with mock.patch.object(venv_lifecycle.subprocess, "run") as ran:
            self.assertFalse(venv_lifecycle.construct(self.base, self.req))
        ran.assert_not_called()

    def test_stale_lock_is_reclaimed(self) -> None:
        lock = self.base / venv_lifecycle.LOCK_FILE
        self.base.mkdir(parents=True, exist_ok=True)
        lock.write_text("", encoding="utf-8")
        old = time.time() - venv_lifecycle.LOCK_STALE_SECONDS - 60
        os.utime(lock, (old, old))
        fd = venv_lifecycle._acquire_lock(self.base)
        self.addCleanup(venv_lifecycle._release_lock, self.base, fd)
        self.assertIsNotNone(fd)

    def test_pip_argv_prefers_lock_file(self) -> None:
        argv = venv_lifecycle._pip_install_argv(Path("pip"), self.req)
        self.assertIn("--only-binary=:all:", argv)
        self.assertNotIn("--require-hashes", argv)

        lock = self.req.with_name("requirements.lock")
        lock.write_text("fastembed==0.3.0 --hash=sha256:abc\n", encoding="utf-8")
        argv = venv_lifecycle._pip_install_argv(Path("pip"), self.req)
        self.assertIn("--require-hashes", argv)
        self.assertIn(str(lock), argv)


class HookWiringTests(unittest.TestCase):
    """Guard the hook contracts that the Python side cannot enforce alone."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp_venv_base = Path(self._tmp.name)
        self.hooks_json = _PLUGIN_ROOT / "hooks" / "hooks.json"
        self.session_start = (_PLUGIN_ROOT / "references" / "scripts" / "hooks"
                              / "build_index_on_start.sh")
        self.prompt = (_PLUGIN_ROOT / "references" / "scripts" / "hooks"
                       / "route_prompt.sh")

    def test_user_prompt_timeout_is_at_least_30(self) -> None:
        data = json.loads(self.hooks_json.read_text(encoding="utf-8"))
        entry = data["hooks"]["UserPromptSubmit"][0]["hooks"][0]
        self.assertGreaterEqual(entry["timeout"], 30)
        self.assertEqual(entry["shell"], "bash")

    def test_session_start_timeout_covers_construction(self) -> None:
        data = json.loads(self.hooks_json.read_text(encoding="utf-8"))
        entry = data["hooks"]["SessionStart"][0]["hooks"][0]
        self.assertGreaterEqual(entry["timeout"], 360)

    @staticmethod
    def _code_only(path: Path) -> str:
        """コメント行を除いた本文。コメントに書かれた手順説明が
        順序アサーションに誤ヒットするのを防ぐ。"""
        return "\n".join(line for line in path.read_text(encoding="utf-8").splitlines()
                         if not line.lstrip().startswith("#"))

    def test_session_start_uses_the_single_prepare_call(self) -> None:
        """順序制約を Python 側に閉じ込め、フックは 1 回だけ起動すること。"""
        code = self._code_only(self.session_start)
        self.assertIn('"$lifecycle" prepare', code)
        for individual in ('"$lifecycle" session-reset',
                           '"$lifecycle" cleanup-if-stale',
                           '"$lifecycle" ensure'):
            self.assertNotIn(individual, code,
                             f"{individual} は prepare に統合済みのはず")

    def test_prepare_runs_cleanup_before_ensure(self) -> None:
        """prepare の内部順序: 撤去 → 構築 → インタプリタ解決。"""
        calls: list[str] = []
        args = argparse.Namespace(base=None, venv_base=str(self.tmp_venv_base),
                                  plugin_root=".", ttl_hours=None,
                                  no_construct=True)
        with mock.patch.object(venv_lifecycle, "cmd_session_reset",
                               side_effect=lambda a: calls.append("reset") or 0), \
             mock.patch.object(venv_lifecycle, "cmd_cleanup_if_stale",
                               side_effect=lambda a: calls.append("cleanup") or 0), \
             mock.patch.object(venv_lifecycle, "cmd_ensure",
                               side_effect=lambda a: calls.append("ensure") or 0), \
             mock.patch.object(venv_lifecycle, "cmd_python_bin",
                               side_effect=lambda a: calls.append("python-bin") or 0):
            rc = venv_lifecycle.cmd_prepare(args)
        self.assertEqual(rc, 0)
        self.assertEqual(calls, ["reset", "cleanup", "ensure", "python-bin"])

    def test_prompt_hook_does_not_run_cleanup(self) -> None:
        self.assertNotIn("cleanup-if-stale", self._code_only(self.prompt))

    def test_traps_never_remove_a_parent_directory(self) -> None:
        """EXIT トラップが自分で作っていないディレクトリを再帰削除しないこと。

        `mktemp` が返すのは `/tmp/tmp.XXXX` のようなファイルであり、その親を
        `rm -rf` するとシステムの一時領域ごと消える。再帰削除は自前で作成した
        ディレクトリを保持する変数に限定する。
        """
        for path in (self.session_start, self.prompt):
            for line in self._code_only(path).splitlines():
                if not line.strip().startswith("trap "):
                    continue
                self.assertNotIn("dirname", line,
                                 f"{path.name}: トラップが親ディレクトリを算出している")
                if "rm -rf" in line:
                    self.assertIn("$fallback_dir", line,
                                  f"{path.name}: 再帰削除の対象が自前作成分に限定されていない")

    def test_prompt_hook_always_exits_zero(self) -> None:
        body = self.prompt.read_text(encoding="utf-8")
        code = [line.strip() for line in body.splitlines()
                if line.strip().startswith("exit ")]
        self.assertTrue(code)
        for line in code:
            self.assertEqual(line, "exit 0")


class LifecycleLogTests(unittest.TestCase):
    """`venv-lifecycle.log` に残す文字列を固定する。

    venv の撤去・構築はフックが出力を捨てるため利用者からは不可視で、
    eval `case-24` / `case-26` はこのログの文言を切り分けの根拠として
    明記している。書式が変わると evals との対応が黙って外れる。
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def _log(self) -> str:
        return (self.base / "venv-lifecycle.log").read_text(encoding="utf-8")

    def test_teardown_records_removal(self) -> None:
        venv_lifecycle.venv_dir(self.base).mkdir(parents=True)
        self.assertTrue(venv_lifecycle.teardown(self.base))
        self.assertIn("teardown removed=True", self._log())
        self.assertIn(str(venv_lifecycle.venv_dir(self.base)), self._log())

    def test_teardown_records_the_lock_conflict(self) -> None:
        (self.base / venv_lifecycle.LOCK_FILE).write_text("", encoding="utf-8")
        self.assertFalse(venv_lifecycle.teardown(self.base))
        self.assertIn("teardown skipped: lock held by another session",
                      self._log())

    def test_log_does_not_follow_a_symlink(self) -> None:
        outside = Path(self._tmp.name).parent / "vl-outside.txt"
        outside.write_text("keep me", encoding="utf-8")
        self.addCleanup(lambda: outside.unlink(missing_ok=True))
        try:
            os.symlink(outside, self.base / "venv-lifecycle.log")
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        venv_lifecycle._record_event(self.base, "hello")
        self.assertEqual(outside.read_text(encoding="utf-8"), "keep me")
        self.assertIn("hello", self._log())

    def test_secrets_are_masked(self) -> None:
        venv_lifecycle._record_failure(
            self.base, ["pip index https://user:ghp_AAAAAAAAAAAAAAAAAAAAAAAAAA@x"])
        body = (self.base / "venv-construct.log").read_text(encoding="utf-8")
        self.assertNotIn("ghp_AAAAAAAAAAAAAAAAAAAAAAAAAA", body)


if __name__ == "__main__":
    unittest.main()
