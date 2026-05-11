"""SessionStart-side skill vectorisation for skill-router v0.4+.

For each skill in the index, build a single representative document
from ``description`` / ``use_when`` / ``skip_when`` / ``trigger_phrases``
/ ``evals.prompt`` and embed it with :mod:`embedding_client`.  The
resulting vectors are persisted as a NumPy ``.npz`` cache so the next
SessionStart only recomputes entries whose source text changed.

Cache layout
------------
::

  <base>/embeddings_cache/
    vectors.npz        # numpy archive: ``vectors`` (N, D)
    manifest.json      # {schema_version, vectors_sha256,
                       #  entries: {qualified_name -> {content_hash, model, idx}}}

The split into ``manifest.json`` (small, fast to load for hit checks)
and ``vectors.npz`` (large, only loaded when needed) keeps cache
queries cheap during SessionStart's hot path.  The manifest also
records the vectors file's SHA-256 so :func:`load_vectors` can refuse
to use a tampered ``vectors.npz``.

Failure semantics
-----------------
All public functions return an empty mapping / leave ``skills``
unchanged on any failure (SDK missing, IO error, model unavailable).
This preserves the heuristic-only behaviour exactly.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import embedding_client  # noqa: E402

try:  # pragma: no cover - optional dependency
    import numpy as _np  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    _np = None  # type: ignore


CACHE_DIR_NAME = "embeddings_cache"
VECTORS_FILE = "vectors.npz"
MANIFEST_FILE = "manifest.json"
CACHE_SCHEMA_VERSION = 1


# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------


def compute_skill_text(skill: dict[str, Any]) -> str:
    """Build the canonical text input fed into the embedder.

    Includes every field that should influence similarity.  Order is
    fixed so byte-identical inputs produce byte-identical hashes; this
    keeps ``content_hash`` stable across runs.
    """
    parts: list[str] = []
    name = skill.get("skill_name") or skill.get("qualified_name", "")
    if name:
        parts.append(f"Skill: {name}")
    desc = skill.get("description", "")
    if desc:
        parts.append(desc)
    use_when = skill.get("use_when", "")
    if use_when:
        parts.append(f"Use when: {use_when}")
    skip_when = skill.get("skip_when", "")
    if skip_when:
        parts.append(f"Skip when: {skip_when}")
    triggers = skill.get("trigger_phrases", []) or []
    if triggers:
        parts.append("Triggers: " + " / ".join(str(t) for t in triggers if t))
    eval_prompts = [
        c.get("prompt", "")
        for c in (skill.get("evals") or [])
        if isinstance(c, dict) and c.get("prompt")
    ]
    if eval_prompts:
        parts.append("Examples: " + " | ".join(eval_prompts))
    return "\n".join(parts).strip()


def compute_content_hash(skill: dict[str, Any]) -> str:
    digest = hashlib.sha256(
        compute_skill_text(skill).encode("utf-8", errors="replace")
    )
    return digest.hexdigest()


# ---------------------------------------------------------------------------
# Cache I/O
# ---------------------------------------------------------------------------


def cache_dir(base: Path) -> Path:
    return base / CACHE_DIR_NAME


def manifest_path(base: Path) -> Path:
    return cache_dir(base) / MANIFEST_FILE


def vectors_path(base: Path) -> Path:
    return cache_dir(base) / VECTORS_FILE


def load_manifest(base: Path) -> dict[str, dict[str, Any]]:
    """Return ``{qualified_name -> entry}`` or ``{}`` on miss/error.

    Rejects the entire cache when the on-disk schema_version differs
    from :data:`CACHE_SCHEMA_VERSION`; treating a version mismatch as
    a full miss keeps the loader simple and forces a clean rebuild on
    the next SessionStart (impl review H-2).
    """
    path = manifest_path(base)
    if not path.is_file():
        return {}
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict):
        return {}
    if data.get("schema_version") != CACHE_SCHEMA_VERSION:
        return {}
    entries = data.get("entries")
    if not isinstance(entries, dict):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for qn, val in entries.items():
        if isinstance(qn, str) and isinstance(val, dict):
            out[qn] = val
    return out


def load_vectors(base: Path, *, expected_sha256: str | None = None) -> Any | None:
    """Return the cached vector matrix or ``None``.

    The matrix is shape ``(N, D)`` where rows are indexed via the
    manifest's ``idx`` field for the corresponding qualified_name.

    Validates dtype/shape and -- when ``expected_sha256`` is supplied --
    the SHA-256 of the raw file bytes.  Mismatch returns ``None`` so
    the caller falls back to the heuristic-only path; this defeats
    tampering scenarios where another process rewrites
    ``vectors.npz`` while leaving the manifest indices intact
    (security review H-1).
    """
    if _np is None:
        return None
    path = vectors_path(base)
    if not path.is_file():
        return None
    if expected_sha256:
        try:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError:
            return None
        if digest != expected_sha256:
            return None
    try:
        with _np.load(path, allow_pickle=False) as archive:
            arr = _np.asarray(archive["vectors"], dtype=_np.float32)
    except Exception:
        return None
    if arr.ndim != 2 or arr.shape[0] == 0 or arr.shape[1] == 0:
        return None
    return arr


def vectors_sha256(base: Path) -> str | None:
    """Return the SHA-256 hex digest of the vectors.npz file.

    Used by ``ensure_skill_vectors`` to record the integrity hash that
    :func:`load_vectors` verifies on the next read.  Returns ``None``
    when the file is missing or unreadable.
    """
    path = vectors_path(base)
    if not path.is_file():
        return None
    try:
        return hashlib.sha256(path.read_bytes()).hexdigest()
    except OSError:
        return None


def save_cache(
    base: Path,
    manifest: dict[str, dict[str, Any]],
    matrix: Any,
) -> None:
    """Persist manifest + vectors atomically.  Fail-open.

    Write order:
      1. ``vectors.npz`` (so its SHA-256 can be embedded in the manifest)
      2. ``manifest.json`` (carries ``vectors_sha256`` for integrity check)

    If step 2 fails, ``vectors.npz`` is left in place but the previous
    manifest still points at the *old* vector indices; the new vectors
    file becomes orphaned but causes no incorrect routing because the
    manifest's ``vectors_sha256`` mismatches and ``load_vectors`` will
    refuse to use the file (security review H-1, impl review M-3).

    ``np.savez`` is given an open file handle so numpy does not
    re-suffix the output path (passing a ``Path`` would produce
    ``<path>.npz`` and break the atomic ``os.replace`` step).

    Stale ``*.tmp`` files left by a crash mid-write are cleaned up in
    the finally block.
    """
    if _np is None:
        return
    vfinal = vectors_path(base)
    vtmp = vfinal.with_name(vfinal.name + ".tmp")
    mfinal = manifest_path(base)
    mtmp = mfinal.with_name(mfinal.name + ".tmp")
    try:
        cache_dir(base).mkdir(parents=True, exist_ok=True)
        with vtmp.open("wb") as fh:
            _np.savez(fh, vectors=matrix)
        os.replace(vtmp, vfinal)
        digest = vectors_sha256(base) or ""
        manifest_payload = {
            "schema_version": CACHE_SCHEMA_VERSION,
            "generated_at": datetime.now(timezone.utc)
            .astimezone()
            .isoformat(timespec="seconds"),
            "vectors_sha256": digest,
            "entries": manifest,
        }
        with mtmp.open("w", encoding="utf-8") as fh:
            json.dump(manifest_payload, fh, ensure_ascii=False, indent=2)
        os.replace(mtmp, mfinal)
        if os.name == "posix":
            try:
                os.chmod(vfinal, 0o600)
                os.chmod(mfinal, 0o600)
            except OSError:
                pass
    except OSError:
        return
    finally:
        for tmp in (vtmp, mtmp):
            if tmp.exists():
                try:
                    tmp.unlink()
                except OSError:
                    pass


def load_vectors_sha256_from_manifest(base: Path) -> str | None:
    """Read the ``vectors_sha256`` field from manifest.json or return None."""
    path = manifest_path(base)
    if not path.is_file():
        return None
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    sha = data.get("vectors_sha256")
    return sha if isinstance(sha, str) and sha else None


# ---------------------------------------------------------------------------
# Vectorisation
# ---------------------------------------------------------------------------


def ensure_skill_vectors(
    skills: list[dict[str, Any]],
    base: Path,
    cfg: embedding_client.EmbeddingConfig,
) -> tuple[dict[str, int], Any | None]:
    """Refresh the on-disk cache and return (qn -> row_index, vectors).

    Returns ``({}, None)`` on any failure path so callers can skip the
    embedding contribution entirely.
    """
    if not skills or not cfg.enabled:
        return {}, None
    if not embedding_client.is_sdk_available() or _np is None:
        return {}, None

    manifest = load_manifest(base)
    existing_matrix = load_vectors(base)

    # Build (qualified_name, content_hash, cached_row_idx) triples.
    rows: list[tuple[str, str, int | None]] = []
    for skill in skills:
        qn = skill.get("qualified_name")
        if not qn:
            continue
        digest = compute_content_hash(skill)
        cached = manifest.get(qn)
        cached_idx: int | None = None
        if (
            isinstance(cached, dict)
            and cached.get("content_hash") == digest
            and cached.get("model") == cfg.model
            and isinstance(cached.get("idx"), int)
        ):
            cached_idx = int(cached["idx"])
        rows.append((qn, digest, cached_idx))

    if not rows:
        return {}, None

    # Identify skills that need (re)embedding.
    pending: list[tuple[int, dict[str, Any]]] = []
    for i, (qn, _digest, cached_idx) in enumerate(rows):
        if cached_idx is None or existing_matrix is None or cached_idx >= existing_matrix.shape[0]:
            pending.append((i, _skill_by_qn(skills, qn)))
        # else: vector reusable from existing_matrix[cached_idx]

    if pending:
        pending = pending[: cfg.max_skills_per_run]
        model = embedding_client.get_model(cfg, base)
        if model is None:
            # Fall through: best-effort reuse of cached rows that *do* exist.
            new_vectors_per_idx: dict[int, Any] = {}
        else:
            texts = [compute_skill_text(skill) for _, skill in pending]
            batch = embedding_client.embed_many(model, texts)
            if batch is None:
                new_vectors_per_idx = {}
            else:
                new_vectors_per_idx = {
                    pending_idx: batch[k]
                    for k, (pending_idx, _) in enumerate(pending)
                }
    else:
        new_vectors_per_idx = {}

    # Compose the final matrix in the same row order as ``rows``.
    final_vectors: list[Any] = []
    final_manifest: dict[str, dict[str, Any]] = {}
    timestamp = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    for i, (qn, digest, cached_idx) in enumerate(rows):
        if i in new_vectors_per_idx:
            vec = new_vectors_per_idx[i]
        elif cached_idx is not None and existing_matrix is not None:
            vec = existing_matrix[cached_idx]
        else:
            # No cache, no fresh embed: skip this skill.
            continue
        final_manifest[qn] = {
            "content_hash": digest,
            "model": cfg.model,
            "idx": len(final_vectors),
            "generated_at": timestamp,
        }
        final_vectors.append(vec)

    if not final_vectors:
        return {}, None

    matrix = _np.stack([_np.asarray(v, dtype=_np.float32) for v in final_vectors])
    save_cache(base, final_manifest, matrix)
    qn_to_idx = {qn: entry["idx"] for qn, entry in final_manifest.items()}
    return qn_to_idx, matrix


def _skill_by_qn(skills: list[dict[str, Any]], qn: str) -> dict[str, Any]:
    for s in skills:
        if s.get("qualified_name") == qn:
            return s
    return {}


# ---------------------------------------------------------------------------
# Diagnostic helpers (used by /router-embedding-cache command)
# ---------------------------------------------------------------------------


def cache_stats(base: Path) -> dict[str, Any]:
    """Return small JSON-friendly stats for the cache."""
    manifest = load_manifest(base)
    vec_path = vectors_path(base)
    matrix = load_vectors(base) if _np is not None else None
    return {
        "manifest_path": str(manifest_path(base)),
        "vectors_path": str(vec_path),
        "entries": len(manifest),
        "rows": int(matrix.shape[0]) if matrix is not None else 0,
        "dim": int(matrix.shape[1]) if matrix is not None and matrix.ndim == 2 else 0,
        "size_bytes": vec_path.stat().st_size if vec_path.is_file() else 0,
        "models": sorted({e.get("model", "") for e in manifest.values() if isinstance(e, dict)}),
    }


def filter_qn_iter(manifest: dict[str, dict[str, Any]], qns: Iterable[str]) -> dict[str, dict[str, Any]]:
    valid = set(qns)
    return {qn: rec for qn, rec in manifest.items() if qn in valid}
