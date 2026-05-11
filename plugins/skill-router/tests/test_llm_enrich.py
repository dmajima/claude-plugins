"""Unit tests for ``llm_enrich`` (Phase A offline enrichment).

The Anthropic SDK is mocked at the ``llm_client`` boundary so these
tests run offline.  We exercise:

- content hashing stability
- cache I/O round-trip
- response sanitisation (trim, dedupe, length caps)
- apply_enrichment_to_skills mutation contract
- enrich_skills no-op paths (disabled, missing SDK, missing key)
- enrich_skills happy path with a fake LLM response

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_llm_enrich.py
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
import llm_enrich  # noqa: E402


def _skill(qn: str = "p:s", **kwargs) -> dict:
    base = {
        "qualified_name": qn,
        "skill_name": qn.split(":")[-1],
        "description": "Convert markdown to PDF",
        "use_when": "user wants a PDF",
        "skip_when": "target is HTML",
        "trigger_phrases": ["MD を PDF に変換"],
        "evals": [{"prompt": "PDF にして", "kind": "case_md"}],
        "keywords": ["pdf", "markdown", "変換"],
    }
    base.update(kwargs)
    return base


class ComputeContentHashTests(unittest.TestCase):
    def test_same_inputs_produce_same_hash(self) -> None:
        a = _skill()
        b = _skill()
        self.assertEqual(
            llm_enrich.compute_content_hash(a), llm_enrich.compute_content_hash(b)
        )

    def test_description_change_changes_hash(self) -> None:
        a = _skill()
        b = _skill(description="changed")
        self.assertNotEqual(
            llm_enrich.compute_content_hash(a), llm_enrich.compute_content_hash(b)
        )

    def test_eval_change_changes_hash(self) -> None:
        a = _skill()
        b = _skill(evals=[{"prompt": "different", "kind": "case_md"}])
        self.assertNotEqual(
            llm_enrich.compute_content_hash(a), llm_enrich.compute_content_hash(b)
        )

    def test_keywords_excluded_from_hash(self) -> None:
        # We deliberately exclude `keywords` from the hash because the
        # enrichment loop adds extra keywords back into that field;
        # including it would invalidate the cache on every run.
        a = _skill()
        b = _skill(keywords=["totally", "different", "list"])
        self.assertEqual(
            llm_enrich.compute_content_hash(a), llm_enrich.compute_content_hash(b)
        )


class CacheIoTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_load_missing_returns_empty(self) -> None:
        self.assertEqual(llm_enrich.load_cache(self.base), {})

    def test_save_then_load_roundtrip(self) -> None:
        entries = {
            "p:s": {
                "content_hash": "abc",
                "model": "claude-x",
                "extra_keywords": ["k1", "k2"],
                "paraphrase_prompts": ["phrase 1"],
                "task_label": "label",
                "generated_at": "2026-05-11T00:00:00+00:00",
            }
        }
        llm_enrich.save_cache(self.base, entries)
        loaded = llm_enrich.load_cache(self.base)
        self.assertEqual(loaded, entries)

    def test_corrupt_cache_returns_empty(self) -> None:
        path = llm_enrich.cache_path(self.base)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("not-json{", encoding="utf-8")
        self.assertEqual(llm_enrich.load_cache(self.base), {})


class NormalizePayloadTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = llm_enrich.EnrichConfig()

    def test_basic_payload_normalised(self) -> None:
        payload = {
            "extra_keywords": ["pdf", "PDF", " PdF ", "markdown"],
            "paraphrase_prompts": ["PDF 化して", "  ", "MD を PDF に"],
            "task_label": "document conversion",
        }
        out = llm_enrich._normalize_payload(payload, self.cfg)
        # Duplicates and whitespace-only entries removed.
        self.assertEqual(out["extra_keywords"], ["pdf", "markdown"])
        self.assertEqual(out["paraphrase_prompts"], ["PDF 化して", "MD を PDF に"])
        self.assertEqual(out["task_label"], "document conversion")

    def test_empty_lists_and_label_returns_none(self) -> None:
        self.assertIsNone(
            llm_enrich._normalize_payload(
                {"extra_keywords": [], "paraphrase_prompts": [], "task_label": ""},
                self.cfg,
            )
        )

    def test_caps_enforced(self) -> None:
        cfg = llm_enrich.EnrichConfig(
            max_keywords_per_skill=2, max_phrases_per_skill=1
        )
        out = llm_enrich._normalize_payload(
            {
                "extra_keywords": ["a", "b", "c", "d"],
                "paraphrase_prompts": ["aa", "bb", "cc"],
                "task_label": "x",
            },
            cfg,
        )
        self.assertEqual(len(out["extra_keywords"]), 2)
        self.assertEqual(len(out["paraphrase_prompts"]), 1)

    def test_non_dict_returns_none(self) -> None:
        self.assertIsNone(llm_enrich._normalize_payload([1, 2], self.cfg))


class ApplyEnrichmentTests(unittest.TestCase):
    def test_keywords_extended_without_duplicates(self) -> None:
        skill = _skill()
        enrichment = {
            "p:s": {
                "extra_keywords": ["PDF", "新キーワード"],  # PDF already present
                "paraphrase_prompts": ["新しい言い換え"],
                "task_label": "convert",
            }
        }
        llm_enrich.apply_enrichment_to_skills([skill], enrichment)
        # Existing 'pdf' (case-insensitive) should not be duplicated.
        lowered = [k.lower() for k in skill["keywords"]]
        self.assertEqual(lowered.count("pdf"), 1)
        self.assertIn("新キーワード", skill["keywords"])

    def test_evals_extended_with_synthetic_paraphrases(self) -> None:
        skill = _skill()
        enrichment = {
            "p:s": {
                "extra_keywords": [],
                "paraphrase_prompts": ["new phrase"],
                "task_label": "",
            }
        }
        llm_enrich.apply_enrichment_to_skills([skill], enrichment)
        synthetic = [c for c in skill["evals"] if c.get("kind") == "llm_paraphrase"]
        self.assertEqual(len(synthetic), 1)
        self.assertEqual(synthetic[0]["prompt"], "new phrase")

    def test_unknown_qualified_name_ignored(self) -> None:
        skill = _skill()
        original_kw = list(skill["keywords"])
        llm_enrich.apply_enrichment_to_skills(
            [skill], {"different:skill": {"extra_keywords": ["zz"]}}
        )
        self.assertEqual(skill["keywords"], original_kw)


class EnrichSkillsNoopPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_disabled_returns_empty(self) -> None:
        out = llm_enrich.enrich_skills(
            [_skill()],
            self.base,
            llm_client.LLMConfig(enabled=False),
            llm_enrich.EnrichConfig(enabled=True),
        )
        self.assertEqual(out, {})

    def test_enrich_disabled_returns_empty(self) -> None:
        out = llm_enrich.enrich_skills(
            [_skill()],
            self.base,
            llm_client.LLMConfig(enabled=True),
            llm_enrich.EnrichConfig(enabled=False),
        )
        self.assertEqual(out, {})

    def test_missing_sdk_returns_empty(self) -> None:
        with mock.patch.object(llm_client, "is_sdk_available", return_value=False):
            out = llm_enrich.enrich_skills(
                [_skill()],
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_enrich.EnrichConfig(enabled=True),
            )
        self.assertEqual(out, {})

    def test_missing_api_key_returns_empty(self) -> None:
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value=None
        ):
            out = llm_enrich.enrich_skills(
                [_skill()],
                self.base,
                llm_client.LLMConfig(enabled=True),
                llm_enrich.EnrichConfig(enabled=True),
            )
        self.assertEqual(out, {})

    def test_cached_skill_skips_llm_call(self) -> None:
        skill = _skill()
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-x")
        digest = llm_enrich.compute_content_hash(skill)
        llm_enrich.save_cache(
            self.base,
            {
                "p:s": {
                    "content_hash": digest,
                    "model": "claude-x",
                    "extra_keywords": ["from-cache"],
                    "paraphrase_prompts": ["cached phrase"],
                    "task_label": "cached",
                    "generated_at": "2026-05-11T00:00:00+00:00",
                }
            },
        )
        # If we ever call the LLM the test fails because get_client returns
        # an object whose .messages.create raises.
        sentinel_client = mock.MagicMock()
        sentinel_client.messages.create.side_effect = AssertionError(
            "should not be called when cache is fresh"
        )
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=sentinel_client
        ):
            out = llm_enrich.enrich_skills(
                [skill],
                self.base,
                llm_cfg,
                llm_enrich.EnrichConfig(enabled=True),
            )
        self.assertIn("p:s", out)
        self.assertEqual(out["p:s"]["extra_keywords"], ["from-cache"])


class IsCleanCacheEntryTests(unittest.TestCase):
    def _good(self) -> dict:
        return {
            "content_hash": "abc",
            "model": "claude-x",
            "extra_keywords": ["a", "b"],
            "paraphrase_prompts": ["c"],
            "task_label": "label",
        }

    def test_good_entry_passes(self) -> None:
        self.assertTrue(llm_enrich._is_clean_cache_entry(self._good()))

    def test_missing_hash_fails(self) -> None:
        bad = self._good()
        del bad["content_hash"]
        self.assertFalse(llm_enrich._is_clean_cache_entry(bad))

    def test_missing_model_fails(self) -> None:
        bad = self._good()
        del bad["model"]
        self.assertFalse(llm_enrich._is_clean_cache_entry(bad))

    def test_non_string_keyword_fails(self) -> None:
        bad = self._good()
        bad["extra_keywords"] = ["ok", 42]
        self.assertFalse(llm_enrich._is_clean_cache_entry(bad))

    def test_non_list_phrases_fails(self) -> None:
        bad = self._good()
        bad["paraphrase_prompts"] = "not a list"
        self.assertFalse(llm_enrich._is_clean_cache_entry(bad))

    def test_load_cache_drops_dirty_entries(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            llm_enrich.cache_path(base).parent.mkdir(parents=True, exist_ok=True)
            llm_enrich.cache_path(base).write_text(
                json.dumps(
                    {
                        "schema_version": 1,
                        "entries": {
                            "good:s": self._good(),
                            "bad:s": {"content_hash": 123, "model": "x"},  # dirty
                        },
                    }
                ),
                encoding="utf-8",
            )
            loaded = llm_enrich.load_cache(base)
            self.assertIn("good:s", loaded)
            self.assertNotIn("bad:s", loaded)


class SanitiseStringListExtraTests(unittest.TestCase):
    def test_newline_in_keyword_dropped(self) -> None:
        out = llm_enrich._sanitise_string_list(
            ["clean", "with\nnewline", "ok"], 10
        )
        self.assertEqual(out, ["clean", "ok"])

    def test_max_len_exceeded_dropped(self) -> None:
        out = llm_enrich._sanitise_string_list(
            ["short", "x" * 200], 10, max_len=40
        )
        self.assertEqual(out, ["short"])

    def test_min_len_enforced(self) -> None:
        out = llm_enrich._sanitise_string_list(
            ["a", "ab", "abc"], 10, min_len=2
        )
        self.assertEqual(out, ["ab", "abc"])

    def test_control_char_dropped(self) -> None:
        out = llm_enrich._sanitise_string_list(["clean", "tab\there"], 10)
        self.assertEqual(out, ["clean"])


class EnrichSkillsHappyPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_writes_cache_after_llm_call(self) -> None:
        skill = _skill()
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-x")
        fake_text = json.dumps(
            {
                "extra_keywords": ["pdf 出力", "ドキュメント変換"],
                "paraphrase_prompts": ["PDF 化お願い"],
                "task_label": "document",
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
            out = llm_enrich.enrich_skills(
                [skill],
                self.base,
                llm_cfg,
                llm_enrich.EnrichConfig(enabled=True),
            )
        self.assertIn("p:s", out)
        self.assertIn("pdf 出力", out["p:s"]["extra_keywords"])
        # Cache should be persisted to disk.
        on_disk = llm_enrich.load_cache(self.base)
        self.assertEqual(
            on_disk["p:s"]["content_hash"],
            llm_enrich.compute_content_hash(skill),
        )

    def test_unparseable_response_skipped(self) -> None:
        skill = _skill()
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-x")
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", return_value="garbage prose only"
        ):
            out = llm_enrich.enrich_skills(
                [skill],
                self.base,
                llm_cfg,
                llm_enrich.EnrichConfig(enabled=True),
            )
        self.assertEqual(out, {})

    def test_max_skills_per_run_limits_calls(self) -> None:
        skills = [_skill(qn=f"p:{i}") for i in range(5)]
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-x")
        enrich_cfg = llm_enrich.EnrichConfig(enabled=True, max_skills_per_run=2)
        responses = iter(
            [
                json.dumps(
                    {"extra_keywords": ["k"], "paraphrase_prompts": [], "task_label": ""}
                )
                for _ in range(10)
            ]
        )
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", side_effect=lambda *a, **kw: next(responses)
        ) as call:
            llm_enrich.enrich_skills(skills, self.base, llm_cfg, enrich_cfg)
        self.assertEqual(call.call_count, 2)

    def test_max_skills_per_run_zero_disables_calls(self) -> None:
        skills = [_skill(qn=f"p:{i}") for i in range(3)]
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-x")
        enrich_cfg = llm_enrich.EnrichConfig(enabled=True, max_skills_per_run=0)
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages"
        ) as call:
            out = llm_enrich.enrich_skills(skills, self.base, llm_cfg, enrich_cfg)
        # No LLM call, no cache write, but the function still returns the
        # (empty) view filtered for the requested qualified names.
        self.assertEqual(call.call_count, 0)
        self.assertEqual(out, {})

    def test_model_change_invalidates_cache(self) -> None:
        skill = _skill()
        digest = llm_enrich.compute_content_hash(skill)
        # Cache was written under a different model.
        llm_enrich.save_cache(
            self.base,
            {
                "p:s": {
                    "content_hash": digest,
                    "model": "claude-OLD",
                    "extra_keywords": ["from-old"],
                    "paraphrase_prompts": [],
                    "task_label": "",
                    "generated_at": "2026-05-11T00:00:00+00:00",
                }
            },
        )
        new_payload = json.dumps(
            {
                "extra_keywords": ["from-new"],
                "paraphrase_prompts": [],
                "task_label": "",
            }
        )
        llm_cfg = llm_client.LLMConfig(enabled=True, model="claude-NEW")
        with mock.patch.object(
            llm_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            llm_client, "resolve_api_key", return_value="key"
        ), mock.patch.object(
            llm_client, "get_client", return_value=object()
        ), mock.patch.object(
            llm_client, "call_messages", return_value=new_payload
        ) as call:
            out = llm_enrich.enrich_skills(
                [skill],
                self.base,
                llm_cfg,
                llm_enrich.EnrichConfig(enabled=True),
            )
        # Different model => cache miss => 1 call.
        self.assertEqual(call.call_count, 1)
        self.assertEqual(out["p:s"]["model"], "claude-NEW")
        self.assertEqual(out["p:s"]["extra_keywords"], ["from-new"])


if __name__ == "__main__":
    unittest.main()
