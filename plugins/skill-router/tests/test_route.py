"""Unit tests for ``route`` core helpers.

Targets the pure scoring helpers (``determine_tier``, ``_skip_phrase_signals``,
``_keyword_overlap``, ``_file_ext_match``, ``load_index``) that don't need
the full hook machinery to exercise.

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_route.py
"""
from __future__ import annotations

import json
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

import route  # noqa: E402


THRESHOLDS = route.DEFAULT_CONFIG["thresholds"]  # high=8.0, ratio=1.25, mid=4.0


class DetermineTierTests(unittest.TestCase):
    def test_high_when_score_and_ratio_satisfied(self) -> None:
        self.assertEqual(route.determine_tier(10.0, 4.0, THRESHOLDS), "high")

    def test_mid_when_score_meets_mid_only(self) -> None:
        self.assertEqual(route.determine_tier(5.0, 4.0, THRESHOLDS), "mid")

    def test_low_when_score_below_mid(self) -> None:
        self.assertEqual(route.determine_tier(2.0, 1.0, THRESHOLDS), "low")

    def test_top1_below_high_score_falls_to_mid_even_with_zero_top2(self) -> None:
        # Critical regression guard: even though top1/max(top2,0.1) becomes
        # very large when top2==0, the AND with top1 >= high_score (8.0)
        # prevents accidental promotion to "high".
        self.assertEqual(route.determine_tier(5.0, 0.0, THRESHOLDS), "mid")

    def test_top1_above_high_with_zero_top2_promotes_to_high(self) -> None:
        # top1 >= 8.0 AND ratio = top1/0.1 = 90.0 (>> 1.25) => high.
        self.assertEqual(route.determine_tier(9.0, 0.0, THRESHOLDS), "high")

    def test_high_score_but_low_ratio_falls_to_mid(self) -> None:
        # top1 >= 8.0 but ratio = 8.0/7.0 = 1.14 < 1.25 => mid.
        self.assertEqual(route.determine_tier(8.0, 7.0, THRESHOLDS), "mid")

    def test_exact_mid_threshold_hits_mid(self) -> None:
        self.assertEqual(route.determine_tier(4.0, 0.0, THRESHOLDS), "mid")

    def test_just_below_mid_threshold_returns_low(self) -> None:
        self.assertEqual(route.determine_tier(3.99, 0.0, THRESHOLDS), "low")


class SkipPhraseSignalsTests(unittest.TestCase):
    def _skill(self, verbs=None, nouns=None) -> dict:
        return {
            "skip_keywords_verb": verbs or [],
            "skip_keywords_noun": nouns or [],
        }

    def test_no_skip_lists_returns_zero(self) -> None:
        self.assertEqual(
            route._skip_phrase_signals(["html", "convert"], self._skill()),
            (0, 0),
        )

    def test_single_noun_match_only(self) -> None:
        # "HTML" present in tokens (uppercase comparison) but no verb match.
        self.assertEqual(
            route._skip_phrase_signals(["html"], self._skill(nouns=["HTML"])),
            (0, 1),
        )

    def test_single_verb_match_only(self) -> None:
        self.assertEqual(
            route._skip_phrase_signals(
                ["変換"], self._skill(verbs=["変換"])
            ),
            (0, 1),
        )

    def test_combo_when_verb_and_noun_both_match(self) -> None:
        self.assertEqual(
            route._skip_phrase_signals(
                ["html", "変換"],
                self._skill(verbs=["変換"], nouns=["HTML"]),
            ),
            (1, 0),
        )

    def test_no_overlap_returns_zero(self) -> None:
        self.assertEqual(
            route._skip_phrase_signals(
                ["pdf"], self._skill(verbs=["変換"], nouns=["HTML"])
            ),
            (0, 0),
        )

    def test_noun_match_is_case_insensitive(self) -> None:
        # tokens contain "HTML" (already upper); skill's nouns are upper too.
        self.assertEqual(
            route._skip_phrase_signals(
                ["HTML"], self._skill(nouns=["html"])
            ),
            (0, 1),
        )


class KeywordOverlapTests(unittest.TestCase):
    def test_overlap_count_capped_at_five(self) -> None:
        prompt_tokens = [f"k{i}" for i in range(10)]
        skill_kw = [f"k{i}" for i in range(10)]
        self.assertEqual(route._keyword_overlap(prompt_tokens, skill_kw), 5)

    def test_no_overlap_returns_zero(self) -> None:
        self.assertEqual(route._keyword_overlap(["a"], ["b"]), 0)

    def test_overlap_is_case_insensitive(self) -> None:
        self.assertEqual(route._keyword_overlap(["Foo"], ["foo"]), 1)


class FileExtMatchTests(unittest.TestCase):
    def test_ext_in_keywords_returns_one(self) -> None:
        self.assertEqual(route._file_ext_match("html", ["HTML", "convert"]), 1)

    def test_ext_missing_returns_zero(self) -> None:
        self.assertEqual(route._file_ext_match("pdf", ["html"]), 0)

    def test_none_ext_returns_zero(self) -> None:
        self.assertEqual(route._file_ext_match(None, ["html"]), 0)


class LoadIndexTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_missing_index_returns_empty(self) -> None:
        self.assertEqual(route.load_index(self.base), {})

    def test_valid_json_returned_as_is(self) -> None:
        payload = {"schema_version": 2, "skills": [{"qualified_name": "x:y"}]}
        (self.base / "index.json").write_text(
            json.dumps(payload), encoding="utf-8"
        )
        self.assertEqual(route.load_index(self.base), payload)

    def test_corrupt_json_returns_empty(self) -> None:
        (self.base / "index.json").write_text("not json{", encoding="utf-8")
        self.assertEqual(route.load_index(self.base), {})

    def test_legacy_pkl_is_ignored(self) -> None:
        # Even if a residual index.pkl exists from an older builder,
        # the loader must NEVER unpickle it (RCE prevention).
        (self.base / "index.pkl").write_bytes(b"would-be-pickle-bytes")
        # No index.json present, so load_index falls through to {}.
        self.assertEqual(route.load_index(self.base), {})


if __name__ == "__main__":
    unittest.main()
