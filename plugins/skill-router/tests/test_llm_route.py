"""Unit tests for ``llm_route`` (Phase B online re-rank).

The Anthropic SDK is mocked at the ``llm_client`` boundary.  Tests cover:

- OnlineConfig parsing and clamping
- should_invoke gating logic (tier / ratio / disabled)
- _coerce_fit clamping
- _apply_fits ordering
- rerank no-op paths and happy path

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_llm_route.py
"""
from __future__ import annotations

import json
import sys
import tempfile
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

import llm_client  # noqa: E402
import llm_route  # noqa: E402


def _row(qn: str, score: float) -> tuple[dict, float, list[str]]:
    return ({"qualified_name": qn, "description": f"desc-{qn}"}, score, [])


class OnlineConfigTests(unittest.TestCase):
    def test_defaults(self) -> None:
        cfg = llm_route.OnlineConfig.from_dict({})
        self.assertFalse(cfg.enabled)
        self.assertEqual(cfg.trigger_tier, "mid")
        self.assertEqual(cfg.max_candidates, 5)

    def test_overrides_applied(self) -> None:
        cfg = llm_route.OnlineConfig.from_dict(
            {
                "enabled": True,
                "trigger_tier": "high",
                "ratio_threshold": 2.0,
                "max_candidates": 10,
                "timeout_sec": 8.0,
                "score_boost": 6.0,
            }
        )
        self.assertTrue(cfg.enabled)
        self.assertEqual(cfg.trigger_tier, "high")
        self.assertEqual(cfg.max_candidates, 10)
        self.assertEqual(cfg.timeout_sec, 8.0)

    def test_invalid_returns_defaults(self) -> None:
        cfg = llm_route.OnlineConfig.from_dict({"max_candidates": "abc"})
        self.assertEqual(cfg, llm_route.OnlineConfig())

    def test_max_candidates_min_clamp(self) -> None:
        cfg = llm_route.OnlineConfig.from_dict({"max_candidates": 0})
        self.assertEqual(cfg.max_candidates, 1)


class ShouldInvokeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = llm_route.OnlineConfig(
            enabled=True, trigger_tier="mid", ratio_threshold=1.5
        )

    def test_disabled_returns_false(self) -> None:
        self.assertFalse(
            llm_route.should_invoke(
                "mid", 5.0, 4.0, llm_route.OnlineConfig(enabled=False)
            )
        )

    def test_wrong_tier_returns_false(self) -> None:
        self.assertFalse(llm_route.should_invoke("high", 10.0, 5.0, self.cfg))
        self.assertFalse(llm_route.should_invoke("low", 1.0, 0.5, self.cfg))

    def test_high_ratio_returns_false(self) -> None:
        # ratio = 5/2 = 2.5 > 1.5, so it's NOT ambiguous enough.
        self.assertFalse(llm_route.should_invoke("mid", 5.0, 2.0, self.cfg))

    def test_low_ratio_returns_true(self) -> None:
        # ratio = 5/4 = 1.25 < 1.5, ambiguous => invoke.
        self.assertTrue(llm_route.should_invoke("mid", 5.0, 4.0, self.cfg))

    def test_zero_top1_returns_false(self) -> None:
        self.assertFalse(llm_route.should_invoke("mid", 0.0, 0.0, self.cfg))


class CoerceFitTests(unittest.TestCase):
    def test_clamps_above_one(self) -> None:
        self.assertEqual(llm_route._coerce_fit(2.5), 1.0)

    def test_clamps_below_zero(self) -> None:
        self.assertEqual(llm_route._coerce_fit(-0.4), 0.0)

    def test_passes_through_in_range(self) -> None:
        self.assertEqual(llm_route._coerce_fit(0.42), 0.42)

    def test_invalid_returns_zero(self) -> None:
        self.assertEqual(llm_route._coerce_fit("not-a-number"), 0.0)
        self.assertEqual(llm_route._coerce_fit(None), 0.0)


class ApplyFitsTests(unittest.TestCase):
    def test_boost_reorders_when_fit_swaps_winner(self) -> None:
        rows = [_row("p:a", 5.0), _row("p:b", 4.0)]
        fits = {"p:a": 0.0, "p:b": 1.0}  # b wins after boost
        out = llm_route._apply_fits(
            rows, fits, llm_route.OnlineConfig(score_boost=4.0)
        )
        self.assertEqual(out[0][0]["qualified_name"], "p:b")
        self.assertAlmostEqual(out[0][1], 4.0 + 4.0 * 1.0)

    def test_unranked_skill_keeps_original_score(self) -> None:
        rows = [_row("p:a", 5.0)]
        out = llm_route._apply_fits(
            rows, {}, llm_route.OnlineConfig(score_boost=4.0)
        )
        self.assertEqual(out[0][1], 5.0)

    def test_reasons_get_llm_annotation_when_fit_present(self) -> None:
        rows = [_row("p:a", 5.0)]
        out = llm_route._apply_fits(
            rows, {"p:a": 0.5}, llm_route.OnlineConfig(score_boost=4.0)
        )
        self.assertTrue(any("llm_fit=" in r for r in out[0][2]))


class RerankNoopPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.rows = [_row("p:a", 5.0), _row("p:b", 4.5)]

    def test_llm_disabled_returns_input(self) -> None:
        out = llm_route.rerank(
            "prompt",
            self.rows,
            self.base,
            llm_client.LLMConfig(enabled=False),
            llm_route.OnlineConfig(enabled=True),
        )
        self.assertIs(out, self.rows)

    def test_online_disabled_returns_input(self) -> None:
        out = llm_route.rerank(
            "prompt",
            self.rows,
            self.base,
            llm_client.LLMConfig(enabled=True),
            llm_route.OnlineConfig(enabled=False),
        )
        self.assertIs(out, self.rows)

    def test_missing_sdk_returns_input(self) -> None:
        with mock.patch.object(llm_client, "is_sdk_available", return_value=False):
            out = llm_route.rerank(
                "prompt",
                self.rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True),
            )
        self.assertIs(out, self.rows)

    def test_missing_api_key_returns_input(self) -> None:
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value=None
        ):
            out = llm_route.rerank(
                "prompt",
                self.rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True),
            )
        self.assertIs(out, self.rows)

    def test_unparseable_response_returns_input(self) -> None:
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", return_value="not json"
        ):
            out = llm_route.rerank(
                "prompt",
                self.rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True),
            )
        self.assertIs(out, self.rows)


class RerankHappyPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_happy_path_reorders(self) -> None:
        rows = [_row("p:a", 5.0), _row("p:b", 4.5), _row("p:c", 4.0)]
        fake_text = json.dumps(
            {
                "matches": [
                    {"skill": "p:a", "fit": 0.0, "reason": "off"},
                    {"skill": "p:b", "fit": 1.0, "reason": "perfect"},
                    {"skill": "p:c", "fit": 0.3, "reason": "weak"},
                ]
            }
        )
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", return_value=fake_text
        ):
            out = llm_route.rerank(
                "prompt",
                rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True, score_boost=4.0),
            )
        # Expected boosted scores:
        #   p:b -> 4.5 + 4.0 * 1.0 = 8.5  (winner)
        #   p:c -> 4.0 + 4.0 * 0.3 = 5.2
        #   p:a -> 5.0 + 4.0 * 0.0 = 5.0
        names = [r[0]["qualified_name"] for r in out]
        scores = [r[1] for r in out]
        self.assertEqual(names, ["p:b", "p:c", "p:a"])
        self.assertAlmostEqual(scores[0], 8.5)
        self.assertAlmostEqual(scores[1], 5.2)
        self.assertAlmostEqual(scores[2], 5.0)

    def test_user_prompt_secrets_masked_before_send(self) -> None:
        # Phase B sends the raw user prompt to the LLM.  Verify that
        # secrets matching session_state's regex set are scrubbed first.
        leaked = "ghp_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        rows = [_row("p:a", 5.0)]
        captured: dict[str, str] = {}

        def _capture_call(client, cfg, *, system, user, **kw):
            captured["user"] = user
            return json.dumps({"matches": [{"skill": "p:a", "fit": 1.0}]})

        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", side_effect=_capture_call
        ):
            llm_route.rerank(
                f"please push with {leaked}",
                rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True),
            )
        # The full token must NOT appear in the outgoing payload, but the
        # masked form (first/last 4 with ***) is acceptable.
        self.assertNotIn(leaked, captured["user"])
        self.assertIn("ghp_", captured["user"])  # masked prefix preserved

    def test_unknown_skill_in_response_ignored(self) -> None:
        rows = [_row("p:a", 5.0), _row("p:b", 4.5)]
        fake_text = json.dumps(
            {
                "matches": [
                    {"skill": "p:zzz", "fit": 1.0, "reason": "fake"},
                    {"skill": "p:a", "fit": 0.5},
                ]
            }
        )
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", return_value=fake_text
        ):
            out = llm_route.rerank(
                "prompt",
                rows,
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_route.OnlineConfig(enabled=True, score_boost=4.0),
            )
        # Only p:a got a boost; p:zzz must not appear.
        names = [r[0]["qualified_name"] for r in out]
        self.assertEqual(set(names), {"p:a", "p:b"})


if __name__ == "__main__":
    unittest.main()
