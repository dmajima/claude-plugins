"""Unit tests for the Bash helper ``commands/resolve_base.sh``.

The shell side owns three invariants that the Python side cannot enforce:

1. ``skill_router_venv_base`` must never resolve into a repository, or a clone
   could supply the interpreter the hooks execute.
2. ``skill_router_venv_python`` must require ``pyvenv.cfg`` alongside the
   executable, so a leftover directory (or a planted one) is not run.
3. ``skill_router_venv_python`` must accept the POSIX layout, where
   ``bin/python`` is a symlink created by ``python -m venv``.

Each test sources the script in a subshell and calls one function, so the
assertions exercise the real file rather than a transcription of it.

Run from the repository root::

    python -m unittest plugins/skill-router/references/scripts/tests/test_resolve_base.py
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPT = (Path(__file__).resolve().parent.parent
           / "commands" / "resolve_base.sh")

_BASH = shutil.which("bash")


def _find_cygpath() -> str | None:
    """Locate ``cygpath``, which Git for Windows keeps off the Windows PATH.

    ``shutil.which`` finds it only when the user added Git's ``usr/bin`` to
    PATH, which is not the default.  Without it the POSIX paths Git Bash
    prints cannot be compared with the Windows paths Python prints, so the
    lock-step tests below must skip rather than compare - silently giving up
    on the conversion made them fail as if the two implementations had
    diverged, which is the one signal they exist to give.
    """
    found = shutil.which("cygpath")
    if found:
        return found
    if not _BASH:
        return None
    # bash.exe は <git>/bin か <git>/usr/bin にあり、cygpath は usr/bin 側。
    bash_dir = Path(_BASH).resolve().parent
    for candidate in (bash_dir / "cygpath.exe",
                      bash_dir.parent / "usr" / "bin" / "cygpath.exe"):
        if candidate.is_file():
            return str(candidate)
    return None


_CYGPATH = _find_cygpath()


@unittest.skipUnless(_BASH, "bash unavailable")
class ResolveBaseShellTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.repo = self.root / "repo"
        (self.repo / ".git").mkdir(parents=True)
        self.home = self.root / "home"
        self.home.mkdir()

    def _run(self, snippet: str, env_extra: dict[str, str] | None = None,
             cwd: Path | None = None) -> subprocess.CompletedProcess:
        env = dict(os.environ)
        env.pop("CLAUDE_PLUGIN_DATA", None)
        env["USERPROFILE"] = str(self.home)
        env["HOME"] = str(self.home)
        env["CLAUDE_PROJECT_DIR"] = str(self.repo)
        if env_extra:
            env.update(env_extra)
        return subprocess.run(
            [_BASH, "-c", f'source "{_SCRIPT.as_posix()}"; {snippet}'],
            capture_output=True, text=True, env=env,
            cwd=str(cwd or self.repo), timeout=60,
        )

    def test_venv_base_never_points_into_the_repository(self) -> None:
        out = self._run("skill_router_venv_base").stdout.strip()
        self.assertTrue(out)
        self.assertNotIn(self.repo.name, out)
        self.assertTrue(out.endswith("plugins/skill-router"), out)

    def test_data_base_may_use_the_repository(self) -> None:
        """`<base>` 側はリポジトリ相対で解決する（venv 側との差を固定）。"""
        out = self._run("skill_router_base").stdout.strip()
        self.assertIn(".claude/.local/plugins/skill-router", out.replace("\\", "/"))

    def test_plugin_data_wins_for_both(self) -> None:
        data = self.root / "plugin-data"
        env = {"CLAUDE_PLUGIN_DATA": str(data)}
        base = self._run("skill_router_base", env).stdout.strip()
        vbase = self._run("skill_router_venv_base", env).stdout.strip()
        self.assertEqual(Path(base), data)
        self.assertEqual(Path(vbase), data)

    def _make_venv(self, root: Path, *, with_cfg: bool, posix_link: bool = False) -> Path:
        vd = root / ".venv"
        if os.name == "nt" and not posix_link:
            exe = vd / "Scripts" / "python.exe"
        else:
            exe = vd / "bin" / "python"
        exe.parent.mkdir(parents=True, exist_ok=True)
        exe.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        exe.chmod(0o755)
        if with_cfg:
            (vd / "pyvenv.cfg").write_text("home = /usr\n", encoding="utf-8")
            # 完了マーカー。pip 成功後にのみ書かれる契約を Bash 側も要求する。
            (root / ".venv-ready").write_text("dummy-hash", encoding="utf-8")
        return exe

    def test_venv_python_requires_pyvenv_cfg(self) -> None:
        data = self.root / "plugin-data"
        data.mkdir()
        self._make_venv(data, with_cfg=False)
        result = self._run("skill_router_venv_python",
                           {"CLAUDE_PLUGIN_DATA": str(data)})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_venv_python_accepts_complete_layout(self) -> None:
        data = self.root / "plugin-data"
        data.mkdir()
        exe = self._make_venv(data, with_cfg=True)
        result = self._run("skill_router_venv_python",
                           {"CLAUDE_PLUGIN_DATA": str(data)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(Path(result.stdout.strip()).name, exe.name)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlink unsupported")
    def test_venv_python_accepts_posix_symlink_layout(self) -> None:
        """POSIX の venv は bin/python を symlink で作る。拒否してはならない。"""
        data = self.root / "plugin-data"
        data.mkdir()
        vd = data / ".venv"
        (vd / "bin").mkdir(parents=True)
        (vd / "pyvenv.cfg").write_text("home = /usr\n", encoding="utf-8")
        (data / ".venv-ready").write_text("dummy-hash", encoding="utf-8")
        real = self.root / "real-python"
        real.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        real.chmod(0o755)
        try:
            os.symlink(real, vd / "bin" / "python")
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        result = self._run("skill_router_venv_python",
                           {"CLAUDE_PLUGIN_DATA": str(data)})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip().endswith("bin/python"))

    def test_repository_venv_is_never_selected(self) -> None:
        """リポジトリ配下に完備の venv があっても選ばれないこと。"""
        repo_data = self.repo / ".claude" / ".local" / "plugins" / "skill-router"
        repo_data.mkdir(parents=True)
        self._make_venv(repo_data, with_cfg=True)
        result = self._run("skill_router_venv_python")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_is_disabled_detects_each_tier(self) -> None:
        data = self.root / "plugin-data"
        data.mkdir()
        env = {"CLAUDE_PLUGIN_DATA": str(data)}
        self.assertNotEqual(
            self._run("skill_router_is_disabled", env).returncode, 0)

        (data / "disabled").write_text("", encoding="utf-8")
        self.assertEqual(
            self._run("skill_router_is_disabled", env).returncode, 0)
        (data / "disabled").unlink()

        repo_flag = (self.repo / ".claude" / ".local" / "plugins"
                     / "skill-router" / "disabled")
        repo_flag.parent.mkdir(parents=True, exist_ok=True)
        repo_flag.write_text("", encoding="utf-8")
        self.assertEqual(self._run("skill_router_is_disabled").returncode, 0)
        repo_flag.unlink()

        home_flag = (self.home / ".claude" / ".local" / "plugins"
                     / "skill-router" / "disabled")
        home_flag.parent.mkdir(parents=True, exist_ok=True)
        home_flag.write_text("", encoding="utf-8")
        self.assertEqual(self._run("skill_router_is_disabled").returncode, 0)

    def test_plugin_data_tilde_is_expanded(self) -> None:
        """`~` 付きの値を Python 側と同じく展開すること（lock-step）。"""
        result = self._run("skill_router_venv_base",
                           {"CLAUDE_PLUGIN_DATA": "~/sr-tilde-test"})
        out = result.stdout.strip()
        self.assertTrue(out)
        # 先頭の ~ が残っていない（Windows の 8.3 短縮名に含まれる ~ は別物）
        self.assertFalse(out.startswith("~"), out)
        self.assertTrue(out.endswith("sr-tilde-test"), out)
        self.assertIn("home", out.replace("\\", "/"), out)

    def test_toggle_round_trips_with_a_tilde_plugin_data(self) -> None:
        """`/router-toggle` の off → status → on がチルダ値でも成立すること。

        フラグを書く側（skill_router_base 経由で正規化済み）と読む側が別々に
        パスを組み立てていた頃は、`~/sr` のような値で off が無音で失効し、
        status は ON と表示し、on でも復帰できなかった。
        """
        toggle = _SCRIPT.parent / "toggle.sh"
        env = {"CLAUDE_PLUGIN_DATA": "~/sr-toggle-test"}

        def run_toggle(action: str) -> subprocess.CompletedProcess:
            full = dict(os.environ)
            full.pop("CLAUDE_PLUGIN_DATA", None)
            full.update({"USERPROFILE": str(self.home), "HOME": str(self.home),
                         "CLAUDE_PROJECT_DIR": str(self.repo)})
            full.update(env)
            return subprocess.run(
                [_BASH, str(toggle), action], capture_output=True, text=True,
                env=full, cwd=str(self.repo), timeout=60)

        run_toggle("off")
        self.assertIn("OFF", run_toggle("status").stdout)
        # フック側の判定と一致していること（ここがずれると OFF が効かない）
        self.assertEqual(
            self._run("skill_router_is_disabled", env).returncode, 0)

        cleared = run_toggle("on")
        self.assertIn("cleared 1 flag(s)", cleared.stdout, cleared.stdout)
        self.assertIn("ON", run_toggle("status").stdout)
        self.assertNotEqual(
            self._run("skill_router_is_disabled", env).returncode, 0)

    def test_venv_python_requires_ready_marker(self) -> None:
        """pip 完了前に中断された venv を採用しないこと。"""
        data = self.root / "plugin-data"
        data.mkdir()
        self._make_venv(data, with_cfg=True)
        (data / ".venv-ready").unlink()
        result = self._run("skill_router_venv_python",
                           {"CLAUDE_PLUGIN_DATA": str(data)})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_base_skips_repository_tier_when_symlinked(self) -> None:
        """リポジトリ層に symlink があれば `<base>` に採用しないこと。"""
        local = self.repo / ".claude" / ".local"
        local.parent.mkdir(parents=True, exist_ok=True)
        outside = self.root / "outside"
        outside.mkdir()
        try:
            os.symlink(outside, local, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("symlink creation not permitted")
        out = self._run("skill_router_base").stdout.strip()
        self.assertNotIn(str(self.repo), out)


    def test_absolute_path_guard_accepts_both_separators(self) -> None:
        """Windows のバックスラッシュ形式も絶対パスとして受理すること。

        両フックが同じ判定を手書きしていた頃、片方のブラケット式が `/` しか
        受理せず、Windows のプロンプト経路だけが venv を採用しない状態に
        なっていた。判定を共有関数へ一本化したうえで両形式を固定する。
        """
        cases = [
            ("C:" + "\\" + "Users" + "\\" + "x" + "\\" + "python.exe", 0),
            ("C:/Users/x/python.exe", 0),
            ("/home/x/.venv/bin/python", 0),
            ("./python.exe", 1),
            ("python3", 1),
            ("", 1),
        ]
        for candidate, expected in cases:
            with self.subTest(candidate=candidate):
                result = self._run(
                    'skill_router_is_absolute_path "%s"' % candidate)
                self.assertEqual(result.returncode, expected, candidate)

    def test_hooks_use_the_shared_absolute_path_guard(self) -> None:
        """両フックが判定を手書きせず共有関数を呼ぶこと。"""
        hooks_dir = _SCRIPT.parent.parent / "hooks"
        for name in ("route_prompt.sh", "build_index_on_start.sh"):
            hook = hooks_dir / name
            body = "\n".join(
                line for line in hook.read_text(encoding="utf-8").splitlines()
                if not line.lstrip().startswith("#"))
            with self.subTest(hook=name):
                self.assertIn("skill_router_is_absolute_path", body)
                self.assertNotIn("[A-Za-z]:", body,
                                 "パス判定を手書きしている")

    def test_toggle_does_not_reimplement_the_tier_walk(self) -> None:
        """`/router-toggle` が階層の知識を持たないこと。

        同じ判断を書き直した結果、正規化の有無が食い違って OFF が無音で
        失効した実績がある。共有関数の利用を構造として固定する。
        """
        body = "\n".join(
            line for line in (_SCRIPT.parent / "toggle.sh")
            .read_text(encoding="utf-8").splitlines()
            if not line.lstrip().startswith("#"))
        self.assertIn("skill_router_is_disabled", body)
        self.assertIn("skill_router_disabled_candidates", body)
        self.assertNotIn("CLAUDE_PLUGIN_DATA", body,
                         "生の環境変数から階層を組み立てている")
        self.assertNotIn(".claude/.local/plugins/skill-router", body,
                         "階層パスを手書きしている")


@unittest.skipUnless(_BASH, "bash unavailable")
class BaseResolutionLockStepTests(unittest.TestCase):
    """Bash 実装と Python 実装が同じディレクトリを返すことを直接照合する。

    `<base>` / `<venv-base>` の解決は 2 言語で二重実装されており、両者の差が
    そのままセキュリティ境界（リポジトリ層を含むか否か）になっている。片側
    だけを変更しても、それぞれ単独の不変条件テストは通ってしまうため、同一の
    環境を与えて出力を突き合わせるのはここでしか担保できない。
    """

    _ROUTING = _SCRIPT.parent.parent / "routing"

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.repo = self.root / "repo"
        (self.repo / ".git").mkdir(parents=True)
        self.home = self.root / "home"
        self.home.mkdir()

    def _env(self, plugin_data: str | None) -> dict[str, str]:
        env = dict(os.environ)
        env.pop("CLAUDE_PLUGIN_DATA", None)
        env.update({"USERPROFILE": str(self.home), "HOME": str(self.home),
                    "CLAUDE_PROJECT_DIR": str(self.repo)})
        if plugin_data is not None:
            env["CLAUDE_PLUGIN_DATA"] = plugin_data
        return env

    def _bash(self, fn: str, env: dict[str, str]) -> str:
        out = subprocess.run(
            [_BASH, "-c", f'source "{_SCRIPT.as_posix()}"; {fn}'],
            capture_output=True, text=True, env=env, cwd=str(self.repo),
            timeout=60).stdout.strip()
        return self._canonical(out)

    def _python(self, expr: str, env: dict[str, str]) -> str:
        code = (f'import sys; sys.path.insert(0, r"{self._ROUTING}");'
                f' import config_io; print({expr})')
        out = subprocess.run(
            [sys.executable, "-c", code], capture_output=True, text=True,
            env=env, cwd=str(self.repo), timeout=60).stdout.strip()
        return self._canonical(out)

    @staticmethod
    def _canonical(value: str) -> str:
        """Reduce a path to a form the two runtimes can be compared in.

        Git Bash prints ``/tmp/...`` (its own mount of the Windows temp
        directory) while Python prints the native form, often carrying an 8.3
        short name (``SOMEUSR~1``).  Converting through ``cygpath`` and then
        materialising + resolving the path collapses both to the same
        canonical long form; comparing the raw strings does not.
        """
        if not value:
            return value
        text = value.strip()
        if text.startswith("/") and os.name == "nt":
            if not _CYGPATH:
                # 変換できないまま比較すると `/tmp/...` が `C:\tmp\...` として
                # 解決され、実装が一致していても不一致に見える。黙って諦める
                # 方が危険なので、明示的にスキップする。
                raise unittest.SkipTest(
                    "cygpath unavailable; cannot compare POSIX and Windows paths")
            converted = subprocess.run(
                [_CYGPATH, "-w", text], capture_output=True, text=True,
                timeout=60).stdout.strip()
            if not converted:
                raise unittest.SkipTest("cygpath conversion produced no output")
            text = converted
        path = Path(text)
        try:
            path.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass
        try:
            path = path.resolve()
        except OSError:
            pass
        return os.path.normcase(str(path))

    def _cases(self) -> list[tuple[str, str | None]]:
        writable = self.root / "plugin-data"
        writable.mkdir(exist_ok=True)
        return [
            ("unset", None),
            ("absolute", str(writable)),
            ("tilde", "~/sr-lockstep"),
            ("padded", f"  {writable}  "),
            ("empty", ""),
        ]

    def test_data_base_matches_between_implementations(self) -> None:
        for label, plugin_data in self._cases():
            with self.subTest(case=label):
                env = self._env(plugin_data)
                self.assertEqual(
                    self._bash("skill_router_base", env),
                    self._python("config_io.resolve_base_dir()", env))

    def test_venv_base_matches_between_implementations(self) -> None:
        for label, plugin_data in self._cases():
            with self.subTest(case=label):
                env = self._env(plugin_data)
                self.assertEqual(
                    self._bash("skill_router_venv_base", env),
                    self._python("config_io.resolve_venv_base()", env))

    def test_repository_tier_difference_is_preserved(self) -> None:
        """`<base>` はリポジトリ配下、`<venv-base>` はホーム側になること。

        両者が一致してしまうと、2 実装が揃って同じ間違いをしても上の 2 件は
        通ってしまう。境界そのものをここで固定する。
        """
        env = self._env(None)
        data = self._bash("skill_router_base", env)
        venv = self._bash("skill_router_venv_base", env)
        self.assertNotEqual(data, venv)
        self.assertIn(self._canonical(str(self.repo)), data)
        self.assertIn(self._canonical(str(self.home)), venv)


if __name__ == "__main__":
    unittest.main()
