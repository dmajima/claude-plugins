"""Unit tests for ``embedding_route`` (UserPromptSubmit boost)."""
from __future__ import annotations

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
import embedding_route  # noqa: E402

try:
    import numpy as np
except ImportError:  # pragma: no cover
    np = None


def _row(qn: str, score: float) -> tuple[dict, float, list[str]]:
    return ({"qualified_name": qn, "description": f"d-{qn}"}, score, [])


@unittest.skipIf(np is None, "numpy not installed")
class BoostRowsNoopPathsTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)
        self.matrix = np.eye(2, dtype=np.float32)
        self.qn_to_idx = {"p:a": 0, "p:b": 1}
        self.rows = [_row("p:a", 5.0), _row("p:b", 4.0)]

    def test_disabled_returns_input(self) -> None:
        out = embedding_route.boost_rows(
            "p",
            self.rows,
            self.base,
            embedding_client.EmbeddingConfig(enabled=False),
            self.qn_to_idx,
            self.matrix,
        )
        self.assertIs(out, self.rows)

    def test_missing_matrix_returns_input(self) -> None:
        out = embedding_route.boost_rows(
            "p",
            self.rows,
            self.base,
            embedding_client.EmbeddingConfig(enabled=True),
            self.qn_to_idx,
            None,
        )
        self.assertIs(out, self.rows)

    def test_empty_map_returns_input(self) -> None:
        out = embedding_route.boost_rows(
            "p",
            self.rows,
            self.base,
            embedding_client.EmbeddingConfig(enabled=True),
            {},
            self.matrix,
        )
        self.assertIs(out, self.rows)

    def test_zero_weight_returns_input(self) -> None:
        out = embedding_route.boost_rows(
            "p",
            self.rows,
            self.base,
            embedding_client.EmbeddingConfig(enabled=True, weight=0.0),
            self.qn_to_idx,
            self.matrix,
        )
        self.assertIs(out, self.rows)

    def test_missing_sdk_returns_input(self) -> None:
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=False
        ):
            out = embedding_route.boost_rows(
                "p",
                self.rows,
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
                self.qn_to_idx,
                self.matrix,
            )
        self.assertIs(out, self.rows)

    def test_model_unavailable_returns_input(self) -> None:
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=None
        ):
            out = embedding_route.boost_rows(
                "p",
                self.rows,
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
                self.qn_to_idx,
                self.matrix,
            )
        self.assertIs(out, self.rows)

    def test_embed_failure_returns_input(self) -> None:
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), mock.patch.object(
            embedding_client, "embed_one", return_value=None
        ):
            out = embedding_route.boost_rows(
                "p",
                self.rows,
                self.base,
                embedding_client.EmbeddingConfig(enabled=True),
                self.qn_to_idx,
                self.matrix,
            )
        self.assertIs(out, self.rows)


@unittest.skipIf(np is None, "numpy not installed")
class BoostRowsHappyPathTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name)

    def test_boost_reorders_when_similarity_swaps_winner(self) -> None:
        # Skill a is heuristic winner (5.0) but embedding orthogonal.
        # Skill b is heuristic 4.0 but embedding matches the query.
        rows = [_row("p:a", 5.0), _row("p:b", 4.0)]
        qn_to_idx = {"p:a": 0, "p:b": 1}
        # Matrix rows pre-normalised: a is [1,0], b is [0,1].
        matrix = np.eye(2, dtype=np.float32)
        query = np.array([0.0, 1.0], dtype=np.float32)  # matches b perfectly
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), mock.patch.object(
            embedding_client, "embed_one", return_value=query
        ):
            out = embedding_route.boost_rows(
                "give me b",
                rows,
                self.base,
                embedding_client.EmbeddingConfig(
                    enabled=True, weight=4.0, min_similarity=0.3
                ),
                qn_to_idx,
                matrix,
            )
        # b: 4.0 + 4.0 * (1.0 - 0.3) = 6.8;  a: 5.0 + 0 (orthogonal, gated)
        names = [r[0]["qualified_name"] for r in out]
        self.assertEqual(names, ["p:b", "p:a"])
        self.assertAlmostEqual(out[0][1], 4.0 + 4.0 * 0.7, places=5)

    def test_below_gate_no_boost(self) -> None:
        rows = [_row("p:a", 5.0)]
        qn_to_idx = {"p:a": 0}
        matrix = np.array([[1.0, 0.0]], dtype=np.float32)
        # Similarity 0.1 (below default 0.3 gate) -> no score change.
        query = np.array([0.1, 0.995], dtype=np.float32)
        query /= np.linalg.norm(query)
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), mock.patch.object(
            embedding_client, "embed_one", return_value=query
        ):
            out = embedding_route.boost_rows(
                "p",
                rows,
                self.base,
                embedding_client.EmbeddingConfig(
                    enabled=True, weight=4.0, min_similarity=0.3
                ),
                qn_to_idx,
                matrix,
            )
        self.assertAlmostEqual(out[0][1], 5.0, places=5)
        # Reason should record the gated similarity for diagnostics.
        joined = " ".join(out[0][2])
        self.assertIn("gated", joined)

    def test_unknown_qn_kept_with_original_score(self) -> None:
        rows = [_row("p:a", 5.0), _row("p:unknown", 4.0)]
        qn_to_idx = {"p:a": 0}
        matrix = np.array([[1.0, 0.0]], dtype=np.float32)
        query = np.array([1.0, 0.0], dtype=np.float32)
        with mock.patch.object(
            embedding_client, "is_sdk_available", return_value=True
        ), mock.patch.object(
            embedding_client, "get_model", return_value=object()
        ), mock.patch.object(
            embedding_client, "embed_one", return_value=query
        ):
            out = embedding_route.boost_rows(
                "p",
                rows,
                self.base,
                embedding_client.EmbeddingConfig(
                    enabled=True, weight=4.0, min_similarity=0.3
                ),
                qn_to_idx,
                matrix,
            )
        # p:unknown receives no boost, p:a gets full match.
        names = {r[0]["qualified_name"] for r in out}
        self.assertEqual(names, {"p:a", "p:unknown"})


if __name__ == "__main__":
    unittest.main()
