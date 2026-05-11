"""Unit tests for ``embedding_client``.

The fastembed SDK is treated as an optional import and faked out at
the module boundary.  These tests run without any network or model
download.

Run from the repository root::

    python -m unittest discover -s plugins/skill-router/tests \\
        -p "test_embedding_client.py"
"""
from __future__ import annotations

import sys
import tempfile
import types
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

try:  # optional: numpy is required for most tests
    import numpy as np
except ImportError:  # pragma: no cover - numpy missing
    np = None


class EmbeddingConfigFromDictTests(unittest.TestCase):
    def test_defaults_when_input_not_dict(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict("not-a-dict")
        self.assertFalse(cfg.enabled)
        self.assertEqual(cfg.model, embedding_client.DEFAULT_MODEL)

    def test_overrides_applied(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict(
            {
                "enabled": True,
                "model": "BAAI/bge-small-en-v1.5",
                "cache_dir": "/tmp/router-models",
                "weight": 4.5,
                "min_similarity": 0.4,
                "max_skills_per_run": 50,
            }
        )
        self.assertTrue(cfg.enabled)
        self.assertEqual(cfg.model, "BAAI/bge-small-en-v1.5")
        self.assertEqual(cfg.cache_dir, "/tmp/router-models")
        self.assertEqual(cfg.weight, 4.5)
        self.assertEqual(cfg.min_similarity, 0.4)
        self.assertEqual(cfg.max_skills_per_run, 50)

    def test_invalid_returns_defaults(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict({"weight": "garbage"})
        self.assertEqual(cfg, embedding_client.EmbeddingConfig())

    def test_clamps_negative_weight(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict({"weight": -1.0})
        self.assertEqual(cfg.weight, 0.0)

    def test_clamps_similarity_out_of_range(self) -> None:
        too_high = embedding_client.EmbeddingConfig.from_dict({"min_similarity": 2.0})
        self.assertEqual(too_high.min_similarity, 1.0)
        too_low = embedding_client.EmbeddingConfig.from_dict({"min_similarity": -1.0})
        self.assertEqual(too_low.min_similarity, 0.0)

    def test_empty_cache_dir_becomes_none(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict({"cache_dir": "   "})
        self.assertIsNone(cfg.cache_dir)


@unittest.skipIf(np is None, "numpy not installed")
class CosineSimilarityTests(unittest.TestCase):
    def test_zero_query_returns_zero_sims(self) -> None:
        query = np.zeros(3, dtype=np.float32)
        # Pre-normalise as the API contract requires.
        matrix = np.array([[1, 0, 0], [0, 1, 0]], dtype=np.float32)
        result = embedding_client.cosine_similarity(query, matrix)
        self.assertIsNotNone(result)
        self.assertTrue(np.allclose(result, [0.0, 0.0]))

    def test_perfect_match_returns_one(self) -> None:
        v = np.array([1.0, 0.0, 0.0], dtype=np.float32)
        matrix = np.stack([v, np.array([0.0, 1.0, 0.0], dtype=np.float32)])
        result = embedding_client.cosine_similarity(v, matrix)
        self.assertAlmostEqual(float(result[0]), 1.0, places=5)
        self.assertAlmostEqual(float(result[1]), 0.0, places=5)

    def test_orthogonal_returns_zero(self) -> None:
        q = np.array([1.0, 0.0], dtype=np.float32)
        m = np.array([[0.0, 1.0]], dtype=np.float32)
        result = embedding_client.cosine_similarity(q, m)
        self.assertAlmostEqual(float(result[0]), 0.0, places=5)

    def test_none_inputs_return_none(self) -> None:
        v = np.array([1.0], dtype=np.float32)
        self.assertIsNone(embedding_client.cosine_similarity(None, v[None, :]))
        self.assertIsNone(embedding_client.cosine_similarity(v, None))

    def test_dim_mismatch_via_shape_check(self) -> None:
        # Query must be 1-D and matrix 2-D; otherwise the function
        # bails out cleanly with None.
        v = np.array([[1.0]], dtype=np.float32)  # 2-D
        m = np.array([[1.0]], dtype=np.float32)
        self.assertIsNone(embedding_client.cosine_similarity(v, m))


class IsSdkAvailableTests(unittest.TestCase):
    def test_with_both_present(self) -> None:
        with mock.patch.object(embedding_client, "_TextEmbedding", object()), \
             mock.patch.object(embedding_client, "_np", object()):
            self.assertTrue(embedding_client.is_sdk_available())

    def test_with_fastembed_missing(self) -> None:
        with mock.patch.object(embedding_client, "_TextEmbedding", None):
            self.assertFalse(embedding_client.is_sdk_available())

    def test_with_numpy_missing(self) -> None:
        with mock.patch.object(embedding_client, "_TextEmbedding", object()), \
             mock.patch.object(embedding_client, "_np", None):
            self.assertFalse(embedding_client.is_sdk_available())


@unittest.skipIf(np is None, "numpy not installed")
class EmbedManyTests(unittest.TestCase):
    def _fake_model(self, vectors):
        m = mock.MagicMock()
        m.embed.return_value = iter(vectors)
        return m

    def test_returns_normalised_matrix(self) -> None:
        vectors = [
            np.array([3.0, 4.0, 0.0], dtype=np.float32),  # norm 5
            np.array([0.0, 0.0, 2.0], dtype=np.float32),  # norm 2
        ]
        model = self._fake_model(vectors)
        out = embedding_client.embed_many(model, ["a", "b"])
        self.assertIsNotNone(out)
        # After L2 normalisation, each row has length 1.
        norms = np.linalg.norm(out, axis=1)
        self.assertTrue(np.allclose(norms, [1.0, 1.0]))

    def test_handles_zero_vector_without_div_by_zero(self) -> None:
        model = self._fake_model([np.zeros(3, dtype=np.float32)])
        out = embedding_client.embed_many(model, ["x"])
        self.assertIsNotNone(out)
        # The norm-zero row is left as zeros; no NaN/inf produced.
        self.assertFalse(np.isnan(out).any())
        self.assertFalse(np.isinf(out).any())

    def test_empty_input_returns_none(self) -> None:
        model = self._fake_model([])
        self.assertIsNone(embedding_client.embed_many(model, []))

    def test_none_model_returns_none(self) -> None:
        self.assertIsNone(embedding_client.embed_many(None, ["x"]))

    def test_embed_one_wraps_single_vector(self) -> None:
        model = self._fake_model([np.array([1.0, 0.0], dtype=np.float32)])
        out = embedding_client.embed_one(model, "x")
        self.assertIsNotNone(out)
        self.assertEqual(out.shape, (2,))

    def test_blank_string_is_replaced_with_space(self) -> None:
        # The wrapper substitutes blank strings with " " so fastembed
        # never sees zero-length input; verify by checking the model
        # received non-empty text.
        called_with = []

        class _M:
            def embed(self, texts):
                called_with.extend(texts)
                return [np.ones(2, dtype=np.float32) for _ in texts]

        out = embedding_client.embed_many(_M(), ["", "  "])
        self.assertIsNotNone(out)
        self.assertEqual(len(called_with), 2)
        for t in called_with:
            self.assertTrue(t.strip() or t == " ")


class GetModelTests(unittest.TestCase):
    def setUp(self) -> None:
        # Reset the singleton cache between tests.
        embedding_client._model_cache.clear()
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_no_sdk_returns_none(self) -> None:
        with mock.patch.object(embedding_client, "_TextEmbedding", None):
            self.assertIsNone(
                embedding_client.get_model(
                    embedding_client.EmbeddingConfig(enabled=True), self.base
                )
            )

    def test_construction_failure_returns_none(self) -> None:
        def boom(**kwargs):
            raise RuntimeError("nope")

        with mock.patch.object(embedding_client, "_TextEmbedding", boom):
            self.assertIsNone(
                embedding_client.get_model(
                    embedding_client.EmbeddingConfig(enabled=True), self.base
                )
            )

    def test_singleton_caches_per_model_and_cache_dir(self) -> None:
        sentinel = object()
        call_count = {"n": 0}

        def fake_ctor(**kwargs):
            call_count["n"] += 1
            return sentinel

        cfg = embedding_client.EmbeddingConfig(enabled=True)
        with mock.patch.object(embedding_client, "_TextEmbedding", fake_ctor):
            a = embedding_client.get_model(cfg, self.base)
            b = embedding_client.get_model(cfg, self.base)
        self.assertIs(a, sentinel)
        self.assertIs(b, sentinel)
        self.assertEqual(call_count["n"], 1)


class MaxSkillsPerRunBoundsTests(unittest.TestCase):
    def test_zero_clamped_to_one(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict({"max_skills_per_run": 0})
        self.assertEqual(cfg.max_skills_per_run, 1)

    def test_negative_clamped_to_one(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict({"max_skills_per_run": -42})
        self.assertEqual(cfg.max_skills_per_run, 1)

    def test_excessive_value_clamped_to_upper_bound(self) -> None:
        cfg = embedding_client.EmbeddingConfig.from_dict(
            {"max_skills_per_run": 99999999}
        )
        self.assertEqual(cfg.max_skills_per_run, 10000)


@unittest.skipIf(np is None, "numpy not installed")
class CosineSimilarityDimensionMismatchTests(unittest.TestCase):
    def test_query_dim_does_not_match_matrix_columns(self) -> None:
        # query has 3 elements but matrix has 4 columns -- numpy raises
        # ValueError, the wrapper must convert it to None.
        q = np.zeros(3, dtype=np.float32)
        m = np.zeros((2, 4), dtype=np.float32)
        self.assertIsNone(embedding_client.cosine_similarity(q, m))


@unittest.skipIf(np is None, "numpy not installed")
class SanitiseInputTests(unittest.TestCase):
    def test_strips_nul_bytes(self) -> None:
        self.assertEqual(
            embedding_client._sanitise_input("hello\x00world"),
            "helloworld",
        )

    def test_caps_long_input(self) -> None:
        long_input = "x" * 20000
        out = embedding_client._sanitise_input(long_input)
        self.assertEqual(len(out), embedding_client._MAX_INPUT_CHARS)

    def test_blank_becomes_space(self) -> None:
        self.assertEqual(embedding_client._sanitise_input(""), " ")
        self.assertEqual(embedding_client._sanitise_input("   "), " ")

    def test_non_string_becomes_space(self) -> None:
        self.assertEqual(embedding_client._sanitise_input(None), " ")
        self.assertEqual(embedding_client._sanitise_input(123), " ")


if __name__ == "__main__":
    unittest.main()
