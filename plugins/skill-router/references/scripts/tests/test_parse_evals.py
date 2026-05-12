"""Unit + golden tests for parse_evals.

Run from the repository root::

    python -m unittest plugins/skill-router/references/scripts/tests/test_parse_evals.py

The golden test exercises the parser against the plugin's real
``skills/skill-router/evals/`` directory so accidental restructuring of
case-XX_*.md files (or removal of recognised prompt patterns) is caught
in CI / pre-push verification.
"""
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

_LIB = Path(__file__).resolve().parent.parent / "lib"
sys.path.insert(0, str(_LIB))

import parse_evals  # noqa: E402


# ---------------------------------------------------------------------------
# _extract_case_md_prompt
# ---------------------------------------------------------------------------


class CaseMdPromptExtractionTests(unittest.TestCase):
    def test_kidou_phrase_table_row(self) -> None:
        text = '| 項目 | 内容 |\n|-----|------|\n| 起動フレーズ | "HTML にして" |\n'
        self.assertEqual(parse_evals._extract_case_md_prompt(text), "HTML にして")

    def test_prompt_table_row_case_insensitive(self) -> None:
        text = "| Prompt | run the index rebuild |\n"
        self.assertEqual(
            parse_evals._extract_case_md_prompt(text), "run the index rebuild"
        )

    def test_text_code_block(self) -> None:
        text = "```text\nrebuild the index\n```\n"
        self.assertEqual(parse_evals._extract_case_md_prompt(text), "rebuild the index")

    def test_quoted_single_line(self) -> None:
        text = '\n"standalone prompt"\n'
        self.assertEqual(parse_evals._extract_case_md_prompt(text), "standalone prompt")

    def test_first_pattern_wins(self) -> None:
        # When multiple patterns could match, the kidou-phrase row
        # (declared first in _CASE_MD_PROMPT_PATTERNS) takes precedence.
        text = (
            '| 起動フレーズ | "primary" |\n'
            "```text\nsecondary\n```\n"
        )
        self.assertEqual(parse_evals._extract_case_md_prompt(text), "primary")

    def test_no_match(self) -> None:
        self.assertIsNone(parse_evals._extract_case_md_prompt("no prompt here"))

    def test_empty_quoted_phrase_does_not_match(self) -> None:
        # Empty "" should not satisfy the [^"]+ requirement.
        self.assertIsNone(parse_evals._extract_case_md_prompt('| 起動フレーズ | "" |\n'))


# ---------------------------------------------------------------------------
# _extract_case_md_expectations
# ---------------------------------------------------------------------------


class CaseMdExpectationsTests(unittest.TestCase):
    def test_extract_bullet_lines(self) -> None:
        text = (
            "## 期待\n"
            "- 第一の期待\n"
            "- 第二の期待\n"
        )
        self.assertEqual(
            parse_evals._extract_case_md_expectations(text),
            ["第一の期待", "第二の期待"],
        )

    def test_stops_at_next_heading(self) -> None:
        text = (
            "## 期待\n"
            "- one\n"
            "## 別セクション\n"
            "- not collected\n"
        )
        self.assertEqual(parse_evals._extract_case_md_expectations(text), ["one"])

    def test_no_expectation_section_returns_empty(self) -> None:
        self.assertEqual(parse_evals._extract_case_md_expectations("# title\n"), [])

    def test_skips_non_bullet_lines(self) -> None:
        text = (
            "## 期待\n"
            "this is description text\n"
            "- captured\n"
            "more text\n"
        )
        self.assertEqual(parse_evals._extract_case_md_expectations(text), ["captured"])

    def test_heading_with_extra_words_does_not_match(self) -> None:
        """Documented design: only ``## 期待`` (exactly) opens an expectation
        block.  Headings like ``## 期待動作`` / ``## 期待出力`` used in
        ``case-04_skip_negative.md`` and ``case-05_diag_no_recommendation.md``
        intentionally fall outside this extractor: those tables are part of
        the human-readable case spec and are NOT supposed to feed back into
        :func:`parse_skill_evals`'s structured output.  If a future change
        starts harvesting those tables, this test will fail loudly so the
        decision is reviewed deliberately rather than slipping in by
        accident."""
        text = "## 期待動作\n- foo\n"
        self.assertEqual(parse_evals._extract_case_md_expectations(text), [])


# ---------------------------------------------------------------------------
# _parse_evals_json
# ---------------------------------------------------------------------------


class ParseEvalsJsonTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.path = Path(self._tmp.name) / "evals.json"

    def _write(self, payload) -> None:
        self.path.write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )

    def test_normal_payload(self) -> None:
        self._write({
            "evals": [
                {"id": "c1", "prompt": "p1", "expectations": ["e1", "e2"]},
                {"id": "c2", "prompt": "p2"},
            ]
        })
        out = parse_evals._parse_evals_json(self.path)
        self.assertEqual(len(out), 2)
        self.assertEqual(out[0], {
            "id": "c1", "prompt": "p1",
            "expectations": ["e1", "e2"], "kind": "json",
        })
        self.assertEqual(out[1]["expectations"], [])

    def test_empty_evals_array(self) -> None:
        self._write({"evals": []})
        self.assertEqual(parse_evals._parse_evals_json(self.path), [])

    def test_blank_or_missing_prompts_skipped(self) -> None:
        self._write({"evals": [
            {"id": "ok", "prompt": "actual"},
            {"id": "blank", "prompt": ""},
            {"id": "missing"},
        ]})
        out = parse_evals._parse_evals_json(self.path)
        self.assertEqual([c["id"] for c in out], ["ok"])

    def test_non_dict_entries_skipped(self) -> None:
        self._write({"evals": [
            {"prompt": "good"},
            "garbage",
            42,
            None,
            {"prompt": "good2"},
        ]})
        out = parse_evals._parse_evals_json(self.path)
        self.assertEqual([c["prompt"] for c in out], ["good", "good2"])

    def test_expectations_filtered_by_type(self) -> None:
        self._write({"evals": [{
            "id": "c", "prompt": "p",
            "expectations": ["str", 42, None, ["nested"], "tail"],
        }]})
        out = parse_evals._parse_evals_json(self.path)
        # str + int are both stringified; None / nested list are dropped.
        self.assertEqual(out[0]["expectations"], ["str", "42", "tail"])

    def test_invalid_json_returns_empty(self) -> None:
        self.path.write_text("not json{", encoding="utf-8")
        self.assertEqual(parse_evals._parse_evals_json(self.path), [])

    def test_top_level_list_treated_as_no_evals(self) -> None:
        # The implementation only honours dicts with an "evals" key.
        self.path.write_text(json.dumps([{"prompt": "x"}]), encoding="utf-8")
        self.assertEqual(parse_evals._parse_evals_json(self.path), [])

    def test_id_defaults_to_empty_string(self) -> None:
        self._write({"evals": [{"prompt": "p"}]})
        out = parse_evals._parse_evals_json(self.path)
        self.assertEqual(out[0]["id"], "")


# ---------------------------------------------------------------------------
# parse_skill_evals integration
# ---------------------------------------------------------------------------


class ParseSkillEvalsIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.skill_dir = Path(self._tmp.name)

    def _evals_dir(self) -> Path:
        d = self.skill_dir / "evals"
        d.mkdir(exist_ok=True)
        return d

    def test_missing_evals_dir_returns_empty(self) -> None:
        self.assertEqual(parse_evals.parse_skill_evals(self.skill_dir), [])

    def test_combines_json_and_md(self) -> None:
        evals_dir = self._evals_dir()
        (evals_dir / "evals.json").write_text(
            json.dumps({"evals": [{"id": "json1", "prompt": "from json"}]}),
            encoding="utf-8",
        )
        (evals_dir / "case-01_demo.md").write_text(
            '| 起動フレーズ | "from md" |\n', encoding="utf-8"
        )
        cases = parse_evals.parse_skill_evals(self.skill_dir)
        # JSON cases come first (they are appended before walking md files).
        self.assertEqual([c["kind"] for c in cases], ["json", "case_md"])
        self.assertEqual([c["prompt"] for c in cases], ["from json", "from md"])

    def test_md_files_are_sorted_alphabetically(self) -> None:
        evals_dir = self._evals_dir()
        (evals_dir / "case-02.md").write_text(
            '| 起動フレーズ | "second" |\n', encoding="utf-8"
        )
        (evals_dir / "case-01.md").write_text(
            '| 起動フレーズ | "first" |\n', encoding="utf-8"
        )
        cases = parse_evals.parse_skill_evals(self.skill_dir)
        self.assertEqual([c["id"] for c in cases], ["case-01", "case-02"])

    def test_unparseable_md_files_are_skipped(self) -> None:
        evals_dir = self._evals_dir()
        (evals_dir / "case-01_bad.md").write_text(
            "# heading only, no recognised prompt pattern\n", encoding="utf-8"
        )
        (evals_dir / "case-02_ok.md").write_text(
            '| 起動フレーズ | "ok" |\n', encoding="utf-8"
        )
        cases = parse_evals.parse_skill_evals(self.skill_dir)
        self.assertEqual([c["id"] for c in cases], ["case-02_ok"])

    def test_evals_dir_present_but_empty_returns_empty(self) -> None:
        self._evals_dir()  # create empty
        self.assertEqual(parse_evals.parse_skill_evals(self.skill_dir), [])


# ---------------------------------------------------------------------------
# Golden test against the plugin's own evals directory
# ---------------------------------------------------------------------------


class GoldenSkillRouterEvalsTests(unittest.TestCase):
    """Catch accidental breakage of prompt extraction against real cases.

    When a contributor restructures one of the case-XX_*.md files in a way
    that drops every recognised prompt pattern, this golden test will fail
    even though the case file is still well-formed Markdown - which is
    exactly the warning we want before the routing index loses signal.
    """

    @classmethod
    def setUpClass(cls) -> None:
        # __file__ lives at <plugin_root>/references/scripts/tests/.
        # Walk up four levels to reach <plugin_root>, then descend into
        # skills/skill-router (the plugin-shipped skill directory).
        cls.skill_dir = (
            Path(__file__).resolve().parent.parent.parent.parent
            / "skills"
            / "skill-router"
        )

    def test_evals_directory_present(self) -> None:
        self.assertTrue(
            (self.skill_dir / "evals").is_dir(),
            f"evals dir missing under {self.skill_dir}",
        )

    def test_every_case_file_yields_a_prompt(self) -> None:
        evals_dir = self.skill_dir / "evals"
        md_files = sorted(evals_dir.glob("case-*.md"))
        self.assertGreater(len(md_files), 0, "no case-*.md files were found")
        cases = parse_evals.parse_skill_evals(self.skill_dir)
        case_md_results = [c for c in cases if c["kind"] == "case_md"]
        # Every case file must yield exactly one entry; otherwise some file
        # has lost its recognised prompt pattern.
        parsed_ids = {c["id"] for c in case_md_results}
        expected_ids = {p.stem for p in md_files}
        missing = expected_ids - parsed_ids
        self.assertFalse(
            missing,
            f"parse_evals failed to extract a prompt from: {sorted(missing)}",
        )
        for entry in case_md_results:
            self.assertTrue(entry["prompt"], f"empty prompt in {entry['id']}")
            self.assertTrue(entry["id"].startswith("case-"))


if __name__ == "__main__":
    unittest.main()
