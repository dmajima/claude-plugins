"""Unit tests for ``text_tokens``.

The tokeniser is shared by the indexer (which writes the inverted index) and
the router (which looks candidates up in it).  A change to one rule that is not
reflected on both sides makes prompt tokens miss postings *silently* - no error,
just no recommendations - so each rule is pinned here rather than being covered
incidentally through the two callers.

Run from the repository root::

    python -m unittest plugins/skill-router/references/scripts/tests/test_text_tokens.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

_LIB = Path(__file__).resolve().parent.parent / "routing"
sys.path.insert(0, str(_LIB))

import text_tokens  # noqa: E402


class ExtractKeywordsTests(unittest.TestCase):
    def test_kanji_run_needs_two_characters(self) -> None:
        self.assertIn("変換", text_tokens.extract_keywords("変換する"))
        # 1 文字の漢字は語として拾わない
        self.assertNotIn("公", text_tokens.extract_keywords("公"))

    def test_katakana_run_needs_four_characters(self) -> None:
        self.assertIn("マークダウン", text_tokens.extract_keywords("マークダウン"))
        self.assertEqual(text_tokens.extract_keywords("カメラ"), [])

    def test_katakana_prolonged_mark_counts(self) -> None:
        # "ー" は文字クラスに含まれる（"ルータ" は 3 文字で落ちる）
        self.assertEqual(text_tokens.extract_keywords("ルータ"), [])
        self.assertIn("ルーター", text_tokens.extract_keywords("ルーター"))

    def test_ascii_is_lowercased(self) -> None:
        self.assertEqual(text_tokens.extract_keywords("PDF"), ["pdf"])

    def test_ascii_needs_two_characters(self) -> None:
        self.assertEqual(text_tokens.extract_keywords("a b"), [])
        self.assertEqual(text_tokens.extract_keywords("ab"), ["ab"])

    def test_english_stopwords_are_dropped(self) -> None:
        out = text_tokens.extract_keywords("the report for this use")
        self.assertEqual(out, ["report"])

    def test_duplicates_collapse_and_order_is_preserved(self) -> None:
        out = text_tokens.extract_keywords("alpha beta ALPHA gamma")
        self.assertEqual(out, ["alpha", "beta", "gamma"])

    def test_multiple_texts_are_merged(self) -> None:
        out = text_tokens.extract_keywords("alpha", "", None, "beta")
        self.assertEqual(out, ["alpha", "beta"])

    def test_mixed_script_input(self) -> None:
        out = text_tokens.extract_keywords("HTMLに変換してマークダウンへ")
        self.assertIn("html", out)
        self.assertIn("変換", out)
        self.assertIn("マークダウン", out)

    def test_empty_input_returns_empty(self) -> None:
        self.assertEqual(text_tokens.extract_keywords(), [])
        self.assertEqual(text_tokens.extract_keywords(""), [])


if __name__ == "__main__":
    unittest.main()
