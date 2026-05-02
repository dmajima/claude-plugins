"""Unit tests for ``session_state``.

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_session_state.py
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from io import StringIO
from pathlib import Path

_LIB = (
    Path(__file__).resolve().parent.parent
    / "references"
    / "scripts"
    / "lib"
)
sys.path.insert(0, str(_LIB))

import session_state  # noqa: E402


class MaskSecretsTests(unittest.TestCase):
    """Cover every regex in :data:`session_state._SECRET_PATTERNS`.

    A failing test here means a credential class is no longer being
    masked before being written to ``prompts.jsonl`` - a serious leak.
    """

    def _masked(self, text: str) -> str:
        return session_state.mask_secrets(text)

    def test_empty_passthrough(self) -> None:
        self.assertEqual(self._masked(""), "")
        self.assertIsNone(self._masked(None))

    def test_openai_sk_token(self) -> None:
        masked = self._masked("use sk-abcdefghijklmnop1234")
        self.assertNotIn("sk-abcdefghijklmnop1234", masked)
        self.assertIn("sk-a***", masked)

    def test_github_pat(self) -> None:
        masked = self._masked("ghp_AbcdefghijklmnopqrstuvwxyzABCDEF12 next")
        self.assertNotIn("ghp_AbcdefghijklmnopqrstuvwxyzABCDEF12", masked)
        self.assertTrue("***" in masked)

    def test_slack_xoxb(self) -> None:
        masked = self._masked("xoxb-1234567890-abcdefghij")
        self.assertNotIn("xoxb-1234567890-abcdefghij", masked)

    def test_aws_access_key(self) -> None:
        masked = self._masked("creds: AKIAIOSFODNN7EXAMPLE here")
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE", masked)

    def test_google_api_key(self) -> None:
        # AIza + 35 chars
        key = "AIza" + ("X" * 35)
        masked = self._masked(f"key={key};")
        self.assertNotIn(key, masked)

    def test_gitlab_pat(self) -> None:
        masked = self._masked("token glpat-AbcdefghijklmnopqrstuvWX!")
        # The "!" is not part of the pattern; the token itself must be masked.
        self.assertNotIn("glpat-AbcdefghijklmnopqrstuvWX", masked)

    def test_jwt(self) -> None:
        jwt = "eyJhbGciOi.eyJzdWIi.SflKxw"
        masked = self._masked(f"Authorization: {jwt}")
        self.assertNotIn(jwt, masked)

    def test_bearer_header(self) -> None:
        masked = self._masked("Authorization: Bearer abcdefghijklmnop1234")
        self.assertNotIn("abcdefghijklmnop1234", masked)

    def test_basic_header(self) -> None:
        masked = self._masked("Authorization: Basic QWxhZGRpbjpPcGVuU2VzYW1l")
        # The base64 payload is masked; "Basic" (the keyword) may still appear.
        self.assertNotIn("QWxhZGRpbjpPcGVuU2VzYW1l", masked)

    def test_unrelated_prose_passes_through(self) -> None:
        original = "no secrets here, just prose"
        self.assertEqual(self._masked(original), original)

    def test_mask_format_is_first4_last4(self) -> None:
        # 20-char token: first4 + *** + last4
        masked = self._masked("sk-abcdefghijklmnop1234")
        self.assertEqual(masked.count("***"), 1)
        # Original boundary chars must be preserved.
        self.assertTrue(masked.startswith("sk-a"))
        self.assertTrue(masked.endswith("1234"))

    def test_short_match_collapses_to_triple_star(self) -> None:
        # Bearer + space + 16 chars exactly = total > 8, so first/last4
        # form is used.  (No pattern in the regex set produces a <=8-char
        # match in normal usage; the <=8 fallback is defensive.)
        masked = self._masked("Bearer abcdefghijklmnop")
        self.assertIn("***", masked)


class IterTailTests(unittest.TestCase):
    def test_returns_last_n_lines(self) -> None:
        lines = ["a\n", "b\n", "c\n", "d\n", "e\n"]
        self.assertEqual(session_state._iter_tail(iter(lines), 3), ["c", "d", "e"])

    def test_n_larger_than_input(self) -> None:
        self.assertEqual(
            session_state._iter_tail(iter(["a\n", "b\n"]), 10), ["a", "b"]
        )

    def test_empty_input(self) -> None:
        self.assertEqual(session_state._iter_tail(iter([]), 5), [])

    def test_n_zero_returns_empty(self) -> None:
        # The loop pops back to size 0 because pop(0) runs whenever len > 0.
        self.assertEqual(session_state._iter_tail(iter(["a\n", "b\n"]), 0), [])


class TailRecentPromptsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.session_id = "sess-test"
        self.prompts_dir = self.base / "sessions" / self.session_id
        self.prompts_dir.mkdir(parents=True)
        self.prompts_path = self.prompts_dir / "prompts.jsonl"

    def _write_lines(self, lines: list[str]) -> None:
        self.prompts_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    def test_missing_file_returns_empty(self) -> None:
        self.assertEqual(
            session_state.tail_recent_prompts(self.base, "missing", 3), []
        )

    def test_n_zero_returns_empty(self) -> None:
        self._write_lines([json.dumps({"prompt": "p1"}),
                           json.dumps({"prompt": "p2"})])
        self.assertEqual(
            session_state.tail_recent_prompts(self.base, self.session_id, 0), []
        )

    def test_returns_last_n_records(self) -> None:
        self._write_lines([json.dumps({"prompt": f"p{i}"}) for i in range(1, 6)])
        out = session_state.tail_recent_prompts(self.base, self.session_id, 3)
        self.assertEqual([r["prompt"] for r in out], ["p3", "p4", "p5"])

    def test_corrupt_lines_are_skipped(self) -> None:
        self._write_lines([
            json.dumps({"prompt": "p1"}),
            "not json{",
            json.dumps({"prompt": "p3"}),
            "still not json",
            json.dumps({"prompt": "p5"}),
        ])
        out = session_state.tail_recent_prompts(self.base, self.session_id, 5)
        # All 5 lines are tail()'d, but only 3 parse cleanly.
        self.assertEqual([r["prompt"] for r in out], ["p1", "p3", "p5"])

    def test_all_corrupt_lines_returns_empty(self) -> None:
        self._write_lines(["not json", "still not json"])
        out = session_state.tail_recent_prompts(self.base, self.session_id, 5)
        self.assertEqual(out, [])


class ResolveSessionIdTests(unittest.TestCase):
    def test_explicit_session_id_preferred(self) -> None:
        sid = session_state.resolve_session_id(
            {"session_id": "my-sess", "transcript_path": "/x"}
        )
        self.assertEqual(sid, "my-sess")

    def test_transcript_path_hashed_when_session_missing(self) -> None:
        sid1 = session_state.resolve_session_id(
            {"transcript_path": "/path/to/transcript.jsonl"}
        )
        sid2 = session_state.resolve_session_id(
            {"transcript_path": "/path/to/transcript.jsonl"}
        )
        self.assertEqual(sid1, sid2)
        self.assertEqual(len(sid1), 64)  # sha256 hex

    def test_env_session_id_used_when_no_transcript(self) -> None:
        import os
        os.environ["CLAUDE_SESSION_ID"] = "env-sess"
        try:
            sid = session_state.resolve_session_id({})
        finally:
            del os.environ["CLAUDE_SESSION_ID"]
        self.assertEqual(sid, "env-sess")

    def test_synthetic_id_is_64_hex(self) -> None:
        # Strip env so the seeded fallback path runs.
        import os
        prev = os.environ.pop("CLAUDE_SESSION_ID", None)
        try:
            sid = session_state.resolve_session_id({})
        finally:
            if prev is not None:
                os.environ["CLAUDE_SESSION_ID"] = prev
        self.assertEqual(len(sid), 64)


class AppendPromptMaskingTests(unittest.TestCase):
    """End-to-end check that append_prompt actually pipes through mask_secrets."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.session_id = "sess-leak"

    def test_secret_is_masked_in_jsonl(self) -> None:
        secret = "sk-abcdefghijklmnop1234"
        session_state.append_prompt(
            self.base, self.session_id,
            {"prompt": f"call API with {secret}", "cwd": "/tmp"},
        )
        path = self.base / "sessions" / self.session_id / "prompts.jsonl"
        body = path.read_text(encoding="utf-8")
        self.assertNotIn(secret, body)
        self.assertIn("***", body)


if __name__ == "__main__":
    unittest.main()
