"""Unit tests for ``config_io`` - base resolution and guarded appends.

Two invariants live here and nowhere else:

1. ``<base>`` skips the repository tier when that tier contains a symlink
   component.  The Bash side has its own test (``test_resolve_base.py``); the
   Python side had none, so removing the guard passed the whole suite.
2. Every append into ``<base>`` goes through :func:`config_io.open_append`,
   which refuses to follow a link and creates the file owner-only.  Both
   properties fail silently when broken - the write simply lands somewhere else,
   or with wider permissions - so they are pinned rather than assumed.

Run from the repository root::

    python -m unittest plugins/skill-router/references/scripts/tests/test_config_io.py
"""
from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

_LIB = Path(__file__).resolve().parent.parent / "routing"
sys.path.insert(0, str(_LIB))

import config_io  # noqa: E402


class ResolveBaseDirTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.repo = self.root / "repo"
        (self.repo / ".git").mkdir(parents=True)
        self.home = self.root / "home"
        self.home.mkdir()
        self._env = mock.patch.dict(
            os.environ,
            {"CLAUDE_PROJECT_DIR": str(self.repo), "HOME": str(self.home),
             "USERPROFILE": str(self.home)},
            clear=False)
        self._env.start()
        self.addCleanup(self._env.stop)
        os.environ.pop("CLAUDE_PLUGIN_DATA", None)

    @staticmethod
    def _expected(root: Path) -> Path:
        # `_project_root` は `.resolve()` を通すため、Windows の 8.3 短縮名
        # （`SOMEUSR~1`）が展開される。期待値も同じ正規化を通して比べる。
        return (root.resolve() / ".claude" / ".local" / "plugins"
                / "skill-router")

    @staticmethod
    def _actual(path: Path) -> Path:
        # 解決経路によって 8.3 短縮名が残る／展開されるが、指すディレクトリは
        # 同一。両辺を resolve + normcase してから比べる。
        try:
            path = path.resolve()
        except OSError:
            pass
        return Path(os.path.normcase(str(path)))

    def test_repository_tier_is_used_by_default(self) -> None:
        self.assertEqual(self._actual(config_io.resolve_base_dir()),
                         self._actual(self._expected(self.repo)))

    def test_repository_tier_is_skipped_when_symlinked(self) -> None:
        """clone が `.claude/.local` をリンクとして同梱した場合に採用しない。

        追従すると、ログ・インデックス・プロンプト履歴の書き込み先を
        リポジトリに選ばれる（リポジトリ外のファイルも指定できる）。
        """
        local = self.repo / ".claude" / ".local"
        local.parent.mkdir(parents=True, exist_ok=True)
        outside = self.root / "outside"
        outside.mkdir()
        try:
            os.symlink(outside, local, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        self.assertEqual(self._actual(config_io.resolve_base_dir()),
                         self._actual(self._expected(self.home)))

    def test_plugin_data_wins_when_writable(self) -> None:
        data = self.root / "plugin-data"
        os.environ["CLAUDE_PLUGIN_DATA"] = str(data)
        self.addCleanup(os.environ.pop, "CLAUDE_PLUGIN_DATA", None)
        self.assertEqual(self._actual(config_io.resolve_base_dir()),
                         self._actual(data))

    def test_venv_base_never_uses_the_repository_tier(self) -> None:
        self.assertEqual(self._actual(config_io.resolve_venv_base()),
                         self._actual(self._expected(self.home)))

    def test_has_symlink_component_walks_ancestors(self) -> None:
        deep = self.repo / "a" / "b" / "c"
        deep.mkdir(parents=True)
        self.assertFalse(config_io._has_symlink_component(deep))
        link = self.repo / "a" / "link"
        try:
            os.symlink(self.root / "home", link, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        self.assertTrue(config_io._has_symlink_component(link / "x" / "y"))


class OpenAppendTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "base"
        self.base.mkdir()
        self.outside = Path(self._tmp.name) / "outside.txt"
        self.outside.write_text("keep me", encoding="utf-8")

    def test_appends_and_creates(self) -> None:
        target = self.base / "error.log"
        with config_io.open_append(target) as fh:
            fh.write("one\n")
        with config_io.open_append(target) as fh:
            fh.write("two\n")
        self.assertEqual(target.read_text(encoding="utf-8"), "one\ntwo\n")

    def test_does_not_follow_a_symlink(self) -> None:
        target = self.base / "error.log"
        try:
            os.symlink(self.outside, target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        with config_io.open_append(target) as fh:
            fh.write("mine\n")
        self.assertEqual(self.outside.read_text(encoding="utf-8"), "keep me")
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(encoding="utf-8"), "mine\n")

    @unittest.skipIf(os.name == "nt", "POSIX permission bits only")
    def test_new_file_is_owner_only(self) -> None:
        """作成時にモードを与える（chmod 後追いだと umask の窓が開く）。"""
        old = os.umask(0o022)
        self.addCleanup(os.umask, old)
        target = self.base / "prompts.jsonl"
        with config_io.open_append(target) as fh:
            fh.write("x\n")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)


class IsReparsePointTests(unittest.TestCase):
    """リンク／ジャンクションの検出。誤検知も見逃しも書き込みを壊す。

    `resolve() != absolute()` で比較すると、8.3 短縮名（`SOMEUSR~1` のような
    形式）を含むパス配下が全て「リダイレクトされている」と判定され、履歴も
    キャッシュも**無音で書かれなくなる**。両辺を `resolve()` に通す形で固定する。
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)

    def test_plain_directory_is_not_a_reparse_point(self) -> None:
        target = self.root / "sessions"
        target.mkdir()
        self.assertFalse(config_io.is_reparse_point(target))

    def test_short_name_path_is_not_a_false_positive(self) -> None:
        """短縮名を含む一時ディレクトリを誤検知しないこと。

        Windows の `%TEMP%` は 8.3 短縮名を含むため、`absolute()` と
        `resolve()` は同じ場所を指しながら文字列が異なる。ここを誤検知すると
        セッション履歴と埋め込みキャッシュが無音で書かれなくなる。
        """
        deep = self.root / "a" / "b" / "embeddings_cache"
        deep.mkdir(parents=True)
        self.assertFalse(config_io.is_reparse_point(deep))

    def test_missing_path_is_not_a_reparse_point(self) -> None:
        self.assertFalse(config_io.is_reparse_point(self.root / "nope"))

    def test_symlinked_directory_is_detected(self) -> None:
        outside = self.root / "outside"
        outside.mkdir()
        link = self.root / "linked"
        try:
            os.symlink(outside, link, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        self.assertTrue(config_io.is_reparse_point(link))

    def test_symlinked_file_is_detected(self) -> None:
        victim = self.root / "victim.txt"
        victim.write_text("x", encoding="utf-8")
        link = self.root / "leaf"
        try:
            os.symlink(victim, link)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        self.assertTrue(config_io.is_reparse_point(link))


class OpenWriteTests(unittest.TestCase):
    """`open_write` は `open_append` と対の防御。同じ水準で固定する。

    切り詰めを伴うぶん追記より破壊的で、リンクを辿れば任意ファイルを空に
    できる。防御コードは削除しても既存テストが緑のままなら意味を失うため、
    リンク非追従・truncate・作成時 0600 をそれぞれ直接検証する。
    """

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "base"
        self.base.mkdir()
        self.outside = Path(self._tmp.name) / "outside.txt"
        self.outside.write_text("keep me", encoding="utf-8")

    def test_truncates_on_reopen(self) -> None:
        target = self.base / "vectors.tmp"
        with config_io.open_write(target) as fh:
            fh.write("first-and-longer")
        with config_io.open_write(target) as fh:
            fh.write("second")
        self.assertEqual(target.read_text(encoding="utf-8"), "second")

    def test_binary_mode_writes_bytes(self) -> None:
        target = self.base / "vectors.npz.tmp"
        with config_io.open_write(target, binary=True) as fh:
            fh.write(b"\x00\x01\x02")
        self.assertEqual(target.read_bytes(), b"\x00\x01\x02")

    def test_does_not_follow_a_symlink(self) -> None:
        target = self.base / "manifest.json.tmp"
        try:
            os.symlink(self.outside, target)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        with config_io.open_write(target) as fh:
            fh.write("mine")
        self.assertEqual(self.outside.read_text(encoding="utf-8"), "keep me")
        self.assertFalse(target.is_symlink())
        self.assertEqual(target.read_text(encoding="utf-8"), "mine")

    @unittest.skipIf(os.name == "nt", "POSIX permission bits only")
    def test_new_file_is_owner_only(self) -> None:
        old = os.umask(0o022)
        self.addCleanup(os.umask, old)
        target = self.base / "fresh.json"
        with config_io.open_write(target) as fh:
            fh.write("x")
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)


class LoadRawConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_missing_returns_empty(self) -> None:
        self.assertEqual(config_io.load_raw_config(self.base), {})

    def test_malformed_returns_empty(self) -> None:
        (self.base / "config.json").write_text("{[", encoding="utf-8")
        self.assertEqual(config_io.load_raw_config(self.base), {})

    def test_non_dict_returns_empty(self) -> None:
        (self.base / "config.json").write_text("[1,2]", encoding="utf-8")
        self.assertEqual(config_io.load_raw_config(self.base), {})

    def test_embedding_section_reads_the_venv_base(self) -> None:
        (self.base / "config.json").write_text(
            json.dumps({"embedding": {"enabled": True, "weight": 2.0}}),
            encoding="utf-8")
        self.assertTrue(config_io.embedding_enabled(self.base))
        self.assertEqual(config_io.embedding_section(self.base)["weight"], 2.0)

    def test_oversized_config_is_ignored(self) -> None:
        """巨大な config.json を毎プロンプト読み込まないこと。

        `<base>` はリポジトリ供給されうる。index 側の 4 MiB 上限と同種の
        ガードで、上限を超えたら内容を見ずに既定へ倒す。
        """
        path = self.base / "config.json"
        padding = "x" * (config_io._MAX_CONFIG_BYTES + 1)
        path.write_text(json.dumps({"pad": padding, "weights": {"a": 1}}),
                        encoding="utf-8")
        self.assertGreater(path.stat().st_size, config_io._MAX_CONFIG_BYTES)
        self.assertEqual(config_io.load_raw_config(self.base), {})

    def test_config_at_the_limit_is_read(self) -> None:
        path = self.base / "config.json"
        payload = {"weights": {"keyword_overlap": 2.0}}
        path.write_text(json.dumps(payload), encoding="utf-8")
        self.assertLessEqual(path.stat().st_size, config_io._MAX_CONFIG_BYTES)
        self.assertEqual(config_io.load_raw_config(self.base), payload)

    def test_merge_is_recursive_and_non_mutating(self) -> None:
        default = {"a": {"x": 1, "y": 2}, "b": 3}
        override = {"a": {"y": 9}}
        merged = config_io.merge(default, override)
        self.assertEqual(merged, {"a": {"x": 1, "y": 9}, "b": 3})
        self.assertEqual(default["a"]["y"], 2)


if __name__ == "__main__":
    unittest.main()
