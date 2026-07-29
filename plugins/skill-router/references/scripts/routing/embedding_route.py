"""UserPromptSubmit-side embedding contribution for skill-router v0.4+.

For each ranked candidate produced by the heuristic scorer, look up
its precomputed vector (built at SessionStart by
:mod:`embedding_enrich`) and compute cosine similarity against the
freshly-embedded user prompt.  The similarity is folded back into the
heuristic score using:

    boosted = heuristic + weight * max(0, similarity - min_similarity)

The subtraction by ``min_similarity`` acts as a noise gate: low
similarities (typical for unrelated skills) contribute zero, so the
boost only ever promotes genuinely related skills.

Failure semantics
-----------------
Every entry point returns the input ``rows`` unchanged on any failure
(SDK missing, model unavailable, embed call failed, NumPy missing).
"""
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import embedding_client  # noqa: E402

try:  # pragma: no cover - optional dependency
    import numpy as _np  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    _np = None  # type: ignore


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def boost_rows(
    user_prompt: str,
    rows: list[tuple[dict[str, Any], float, list[str]]],
    venv_base: Path,
    cfg: embedding_client.EmbeddingConfig,
    qn_to_idx: dict[str, int],
    matrix: Any | None,
) -> list[tuple[dict[str, Any], float, list[str]]]:
    """Return ``rows`` with similarity boosts applied and resorted.

    ``venv_base`` is the user-owned directory holding the ONNX model cache -
    deliberately not ``<base>``, which can resolve inside a checked-out
    repository (see :func:`embedding_client._resolve_cache_dir`).

    ``qn_to_idx`` and ``matrix`` come from
    :func:`embedding_enrich.ensure_skill_vectors`.  When either is
    absent or the SDK is unavailable, ``rows`` is returned unchanged.

    The function re-checks ``cfg.enabled`` and the SDK availability
    even though the caller is expected to have gated on them: this
    keeps the helper safe to call from new callsites and matches the
    fail-open contract documented in the module header.
    """
    if not rows or not cfg.enabled or matrix is None or not qn_to_idx:
        return rows
    if not embedding_client.is_sdk_available() or _np is None:
        return rows
    if cfg.weight <= 0.0:
        return rows
    model = embedding_client.get_model(cfg, venv_base, require_cached=True)
    if model is None:
        return rows
    query = embedding_client.embed_one(model, user_prompt)
    if query is None:
        return rows

    similarities = embedding_client.cosine_similarity(query, matrix)
    if similarities is None:
        return rows

    boosted: list[tuple[dict[str, Any], float, list[str]]] = []
    for skill, score, reasons in rows:
        qn = skill.get("qualified_name", "")
        idx = qn_to_idx.get(qn)
        if idx is None or idx >= similarities.shape[0]:
            boosted.append((skill, score, reasons))
            continue
        sim = float(similarities[idx])
        if sim <= cfg.min_similarity:
            # Below the noise gate -- no boost, but record the raw similarity
            # for diagnostic visibility.
            new_reasons = list(reasons) + [f"embedding_sim={sim:+.2f} (gated)"]
            boosted.append((skill, score, new_reasons))
            continue
        delta = cfg.weight * (sim - cfg.min_similarity)
        new_reasons = list(reasons) + [
            f"embedding_sim={sim:+.2f} (+{delta:.2f})"
        ]
        boosted.append((skill, score + delta, new_reasons))
    boosted.sort(key=lambda r: r[1], reverse=True)
    return boosted
