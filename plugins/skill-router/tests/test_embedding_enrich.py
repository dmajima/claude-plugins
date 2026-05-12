"""Unit tests for ``embedding_enrich`` (SessionStart vectorisation).

fastembed and numpy are mocked at the ``embedding_client`` boundary so
these tests run offline.
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

import embedding_client  # noqa: E402
import embedding_enrich  # noqa: E402

try:
    import numpy as np
except ImportError:  # pragma: no cover
    np = None


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


class ComputeSkillTextTests(unittest.TestCase):
    def test_includes_main_fields(self) -> None:
        text = embedding_enrich.compute_skill_text(_skill())
        self.assertIn("Convert markdown to PDF", text)
        self.assertIn("Use when: user wants a PDF", text)
        self.assertIn("Skip when: target is HTML", text)
        self.assertIn("MD を PDF に変換", text)
        self.assertIn("PDF にして", text)

    def test_empty_skill_does_not_crash(self) -> None:
        self.assertEqual(embedding_enrich.compute_skill_text({}), "")


class ComputeContentHashTests(unittest.TestCase):
    def test_stable_across_calls(self) -> None:
        a = embedding_enrich.compute_content_hash(_skill())
        b = embedding_enrich.compute_content_hash(_skill())
        self.assertEqual(a, b)

    def test_changes_when_description_changes(self) -> None:
        a = embedding_enrich.compute_content_hash(_skill())
        b = embedding_enrich.compute_content_hash(_skill(description="changed"))
        self.assertNotEqual(a, b)

    def test_keywords_excluded_from_hash(self) -> None:
        # keywords mutate during routing; excluding them keeps the cache
        # stable across runs.
        a = embedding_enrich.compute_content_hash(_skill())
        b = embedding_enrich.compute_content_hash(_skill(keywords=["zzz"]))
        self.assertEqual(a, b)


@unittest.skipIf(np is None, "numpy not installed")
class ManifestIoTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_load_missing_returns_empty(self) -> None:
        self.assertEqual(embedding_enrich.load_manifest(self.base), {})

    def test_save_then_load_roundtrip(self) -> None:
        manifest = {
            "p:s": {"content_hash": "h", "model": "m", "idx": 0, "generated_at": "t"}
        }
        matrix = np.zeros((1, 4), dtype=np.float32)
        embedding_enrich.save_cache(self.base, manifest, matrix)
        loaded_manifest = embedding_enrich.load_manifest(self.base)
        loaded_matrix = embedding_enrich.load_vectors(self.base)
        self.assertEqual(loaded_manifest, manifest)
        self.assertIsNotNone(loaded_matrix)
        self.assertEqual(loaded_matrix.shape, (1, 4))

    def test_corrupt_manifest_returns_empty(self) -> None:
        path = embedding_enrich.manifest_path(self.base)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("not-json{", encoding="utf-8")
        self.assertEqual(embedding_enrich.load_manifest(self.base), {})


@unittest.skipIf(np is None, "numpy not installed")
class EnsureSkillVectorsNoopPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_disabled_returns_empty(self) -> None:
        qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
            [_skill()],
            self.base,
            embedding_client.EmbeddingConfig(enabled=False),
        )
        self.assertEqual(qn_to_idx, {})
        self.assertIsNone(matrix)

    def test_empty_skills_returns_empty(self) -> None:
        qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
            [],
            self.base,
            embedding_client.EmbeddingConfig(enabled=True),
        )
        self.assertEqual(qn_to_idx, {})
        self.assertIsNone(matrix)

    def test_missing_sdk_returns_empty(self) -> None:
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=False
        ):
            qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
                [_skill()],
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
            )
        self.assertEqual(qn_to_idx, {})
        self.assertIsNone(matrix)

    def test_model_unavailable_returns_empty(self) -> None:
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=None
        ):
            qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
                [_skill()],
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
            )
        self.assertEqual(qn_to_idx, {})
        self.assertIsNone(matrix)


@unittest.skipIf(np is None, "numpy not installed")
class EnsureSkillVectorsHappyPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def _patch_embed(self, vectors):
        return mock.patch.object(
            embedding_client,
            "embed_many",
            side_effect=lambda model, texts: np.stack(
                [v for v in vectors[: len(texts)]]
            )
            if vectors
            else None,
        )

    def test_first_run_writes_cache(self) -> None:
        skill = _skill()
        v = np.array([0.6, 0.8, 0.0], dtype=np.float32)  # normalised
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), self._patch_embed([v]):
            qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
                [skill],
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
            )
        self.assertEqual(qn_to_idx, {"p:s": 0})
        self.assertEqual(matrix.shape, (1, 3))
        # Cache persisted to disk.
        manifest = embedding_enrich.load_manifest(self.base)
        self.assertIn("p:s", manifest)
        self.assertEqual(
            manifest["p:s"]["content_hash"],
            embedding_enrich.compute_content_hash(skill),
        )

    def test_second_run_reuses_cache(self) -> None:
        skill = _skill()
        v = np.array([0.6, 0.8, 0.0], dtype=np.float32)
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ):
            with self._patch_embed([v]) as call:
                embedding_enrich.ensure_skill_vectors(
                    [skill], self.base, embedding_client.EmbeddingConfig(enabled=True)
                )
                self.assertEqual(call.call_count, 1)
            # Second invocation: same skill, same hash -> no embed call.
            with mock.patch.object(
                embedding_client, "embed_many"
            ) as call2:
                qn_to_idx, matrix = embedding_enrich.ensure_skill_vectors(
                    [skill],
                    self.base,
                    embedding_client.EmbeddingConfig(enabled=True),
                )
        call2.assert_not_called()
        self.assertEqual(qn_to_idx, {"p:s": 0})
        self.assertEqual(matrix.shape, (1, 3))

    def test_model_change_invalidates_cache(self) -> None:
        skill = _skill()
        v = np.array([0.6, 0.8, 0.0], dtype=np.float32)
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ):
            with self._patch_embed([v]):
                embedding_enrich.ensure_skill_vectors(
                    [skill],
                    self.base,
                    embedding_client.EmbeddingConfig(enabled=True, model="model-A"),
                )
            with self._patch_embed([v]) as call:
                embedding_enrich.ensure_skill_vectors(
                    [skill],
                    self.base,
                    embedding_client.EmbeddingConfig(enabled=True, model="model-B"),
                )
        # Different model => re-embed.
        self.assertEqual(call.call_count, 1)

    def test_max_skills_per_run_caps_new_embeds(self) -> None:
        skills = [_skill(qn=f"p:{i}") for i in range(5)]
        v = np.ones(3, dtype=np.float32) / np.sqrt(3)
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), mock.patch.object(
            embedding_client,
            "embed_many",
            side_effect=lambda model, texts: np.stack([v for _ in texts]),
        ) as call:
            embedding_enrich.ensure_skill_vectors(
                skills,
                self.base,
                embedding_client.EmbeddingConfig(enabled=True, max_skills_per_run=2),
            )
        # embed_many is called once but with at most 2 texts.
        self.assertEqual(call.call_count, 1)
        texts_arg = call.call_args[0][1]
        self.assertEqual(len(texts_arg), 2)


@unittest.skipIf(np is None, "numpy not installed")
class IntegrityVerificationTests(unittest.TestCase):
    """Defence-in-depth tests for the v0.4 cache integrity additions."""

    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        # Seed the cache with a known good payload.
        self.matrix = np.array([[0.6, 0.8, 0.0]], dtype=np.float32)
        self.manifest = {
            "p:s": {"content_hash": "h", "model": "m", "idx": 0, "generated_at": "t"}
        }
        embedding_enrich.save_cache(self.base, self.manifest, self.matrix)

    def test_load_vectors_passes_with_correct_hash(self) -> None:
        sha = embedding_enrich.load_vectors_sha256_from_manifest(self.base)
        self.assertIsNotNone(sha)
        out = embedding_enrich.load_vectors(self.base, expected_sha256=sha)
        self.assertIsNotNone(out)
        self.assertEqual(out.shape, (1, 3))

    def test_load_vectors_rejects_tampered_file(self) -> None:
        path = embedding_enrich.vectors_path(self.base)
        # Append a stray byte to corrupt the SHA-256.
        with path.open("ab") as fh:
            fh.write(b"\x00")
        sha = embedding_enrich.load_vectors_sha256_from_manifest(self.base)
        self.assertIsNone(
            embedding_enrich.load_vectors(self.base, expected_sha256=sha)
        )

    def test_load_manifest_rejects_unknown_schema_version(self) -> None:
        path = embedding_enrich.manifest_path(self.base)
        # Re-write with a future schema version.
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
        data["schema_version"] = 999
        path.write_text(json.dumps(data), encoding="utf-8")
        self.assertEqual(embedding_enrich.load_manifest(self.base), {})

    def test_load_vectors_rejects_wrong_dimension_payload(self) -> None:
        # Replace the file with a 1-D archive -- shape check should bail.
        path = embedding_enrich.vectors_path(self.base)
        with path.open("wb") as fh:
            np.savez(fh, vectors=np.array([1, 2, 3], dtype=np.float32))
        self.assertIsNone(embedding_enrich.load_vectors(self.base))

    def test_manifest_entries_signature_recorded(self) -> None:
        m_path = embedding_enrich.manifest_path(self.base)
        with m_path.open("r", encoding="utf-8") as fh:
            payload = json.load(fh)
        self.assertIn("entries_sha256", payload)
        self.assertTrue(payload["entries_sha256"])
        expected = embedding_enrich._compute_entries_signature(self.manifest)
        self.assertEqual(payload["entries_sha256"], expected)

    def test_load_manifest_rejects_tampered_entries(self) -> None:
        # Tamper an entry without recomputing entries_sha256.
        m_path = embedding_enrich.manifest_path(self.base)
        with m_path.open("r", encoding="utf-8") as fh:
            payload = json.load(fh)
        payload["entries"]["p:s"]["content_hash"] = "attacker"
        m_path.write_text(
            json.dumps(payload, ensure_ascii=False), encoding="utf-8"
        )
        # Signature now mismatches -> entire cache is rejected.
        self.assertEqual(embedding_enrich.load_manifest(self.base), {})


@unittest.skipIf(np is None, "numpy not installed")
class SaveCacheCleanupTests(unittest.TestCase):
    def test_no_tmp_files_remain_after_save(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            embedding_enrich.save_cache(
                base,
                {"p:s": {"content_hash": "h", "model": "m", "idx": 0, "generated_at": "t"}},
                np.zeros((1, 4), dtype=np.float32),
            )
            cache = embedding_enrich.cache_dir(base)
            self.assertTrue(cache.is_dir())
            tmp_files = [p for p in cache.iterdir() if p.suffix == ".tmp"]
            self.assertEqual(tmp_files, [])


if __name__ == "__main__":
    unittest.main()
