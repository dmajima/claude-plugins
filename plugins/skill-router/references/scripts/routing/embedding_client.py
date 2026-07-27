"""Local embedding client for skill-router (v0.4 fully offline routing).

A thin wrapper over ``fastembed`` that:

- lazily imports ``fastembed`` and ``numpy`` so the plugin still loads
  when the optional dependencies are unavailable (e.g. before the venv
  is constructed).  In that state every public function falls through
  to a no-op which preserves the heuristic-only behaviour of v0.2.
- caches the loaded ``TextEmbedding`` model in a module-level slot so
  repeated calls within one process amortise the model load cost (the hooks are separate processes, so this does not carry across prompts)
  (model load is the most expensive step at ~1-3s on first call).
- vectorises lists of texts in a single batch call, exposing
  :func:`embed_many` and :func:`embed_one` for callers.

The module deliberately avoids any network call: model download is the
sole responsibility of ``fastembed`` itself (HuggingFace hub on first
load), and operators in air-gapped environments can preposition the
ONNX model under ``cache_dir`` and skip the download.
"""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Force telemetry-suppression env vars to "1" *before* fastembed /
# huggingface_hub are imported, since both libraries cache the values
# at import time.  Using ``setdefault`` here would let a stray ``"0"``
# in the user environment defeat the protection -- so we assign
# unconditionally (security review M-3 / CWE-693).
#
# We deliberately do NOT touch ``TRANSFORMERS_OFFLINE`` /
# ``HF_DATASETS_OFFLINE``: those flags are user-controlled opt-ins for
# air-gapped runs and the plugin must not override an explicit ``"1"``.
os.environ["HF_HUB_DISABLE_TELEMETRY"] = "1"
os.environ["DO_NOT_TRACK"] = "1"

# Lazy / optional imports.  fastembed and numpy may be missing if the
# plugin's venv hasn't been constructed yet; everything below must
# tolerate that and behave as a no-op until they appear.
try:  # pragma: no cover - optional dependency
    import numpy as _np  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    _np = None  # type: ignore

try:  # pragma: no cover - optional dependency
    from fastembed import TextEmbedding as _TextEmbedding  # type: ignore
except Exception:  # pragma: no cover - optional dependency
    _TextEmbedding = None  # type: ignore


DEFAULT_MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class EmbeddingConfig:
    """Top-level ``embedding`` block of ``config.json``.

    All fields are clamped at parse time so a malformed user config
    cannot crash the routing path.
    """

    enabled: bool = False
    model: str = DEFAULT_MODEL
    cache_dir: str | None = None  # None -> <venv-base>/embeddings_cache/models
    weight: float = 3.0
    min_similarity: float = 0.3
    max_skills_per_run: int = 200

    @classmethod
    def from_dict(cls, raw: Any) -> "EmbeddingConfig":
        if not isinstance(raw, dict):
            return cls()
        try:
            cache_raw = raw.get("cache_dir")
            cache_dir = str(cache_raw) if isinstance(cache_raw, str) and cache_raw.strip() else None
            return cls(
                enabled=bool(raw.get("enabled", False)),
                model=str(raw.get("model", DEFAULT_MODEL)) or DEFAULT_MODEL,
                cache_dir=cache_dir,
                # Weight may legitimately be 0 to disable boost; cap at
                # 1000.0 so a tampered config (e.g. ``"weight": 1e308`` or
                # NaN/inf inputs) cannot inject ``inf`` into the routing
                # score and force every prompt to the high tier
                # (impl review H-2).
                weight=max(0.0, min(1000.0, float(raw.get("weight", 3.0)))),
                # Similarity is bounded to [-1, 1]; clamp to a sane window.
                min_similarity=max(0.0, min(1.0, float(raw.get("min_similarity", 0.3)))),
                # Bounded between 1 and 10000 -- the upper cap is a DoS
                # guard against tampered configs that would block
                # SessionStart for tens of minutes (security review M-5).
                max_skills_per_run=max(
                    1, min(10000, int(raw.get("max_skills_per_run", 200)))
                ),
            )
        except (TypeError, ValueError):
            return cls()


# ---------------------------------------------------------------------------
# SDK availability
# ---------------------------------------------------------------------------


def is_sdk_available() -> bool:
    """Return ``True`` iff fastembed and numpy can be imported."""
    return _TextEmbedding is not None and _np is not None


# ---------------------------------------------------------------------------
# Model cache (module-level singleton)
# ---------------------------------------------------------------------------


# Cached as ``(model_name, cache_dir) -> loaded TextEmbedding instance``.
# Loading the ONNX model costs 1-3s the first time; reusing across
# SessionStart -> UserPromptSubmit within the same process saves that.
_model_cache: dict[tuple[str, str | None], Any] = {}


# Windows MAX_PATH is 260.  HuggingFace caches snapshots under
# ``<cache>/models--<org>--<name>/snapshots/<sha>/<file>`` which alone
# eats 80-150 characters; if the user's <base> is deep (e.g. a repo
# checkout under a long path), the resulting absolute path exceeds
# MAX_PATH and ``[WinError 206]`` aborts the download.  Reserve enough
# headroom for the longest model file we ship.
_WINDOWS_CACHE_DIR_HEADROOM = 100  # chars; conservative

# Where to fall back to when the auto-resolved cache dir is too deep
# on Windows.  Kept short (``~/.cache/...``) and shared across all
# bases on the host, which is fine because model ONNX files are
# content-addressed by HuggingFace.
_FALLBACK_CACHE_REL_WINDOWS = ("AppData", "Local", "skill-router", "models")
_FALLBACK_CACHE_REL_POSIX = (".cache", "skill-router", "models")


def _fallback_cache_dir() -> Path:
    """Return the OS-appropriate fallback cache directory for HF models.

    Branching here (rather than at the call site only) ensures any
    future caller that invokes ``_fallback_cache_dir`` directly still
    gets a path that matches platform conventions (impl review M-2).
    """
    home = Path(os.path.expanduser("~"))
    if os.name == "nt":
        return home.joinpath(*_FALLBACK_CACHE_REL_WINDOWS)
    return home.joinpath(*_FALLBACK_CACHE_REL_POSIX)


def _resolve_cache_dir(cfg: EmbeddingConfig, venv_base: Path) -> Path:
    """Pick a cache directory for the fastembed/HuggingFace download.

    ``venv_base`` is the *user-owned* directory (``<venv-base>``), never the
    repository-relative ``<base>``: this cache holds the ONNX graph that
    onnxruntime loads and executes, so letting a checked-out repository supply
    it would hand the prompt path an attacker-chosen model.  Callers therefore
    pass :func:`config_io.resolve_venv_base`; tests pass a temporary directory.

    Resolution:
      1. user-specified ``cfg.cache_dir`` -- respected verbatim (the
         operator presumably knows their environment best).
      2. ``<venv-base>/embeddings_cache/models`` -- the default, fine on
         POSIX and on Windows when ``<venv-base>`` is shallow.
      3. On Windows only, when (2) would push paths past MAX_PATH,
         fall back to ``~/AppData/Local/skill-router/models`` and log
         a warning so operators can opt out via ``cfg.cache_dir``.
    """
    if cfg.cache_dir:
        # Deliberately honoured verbatim: overriding this is the documented
        # escape hatch for Windows MAX_PATH (see README), so constraining it to
        # plugin-owned directories would break the very case it exists for.
        # The whole ``embedding`` block is read from <venv-base>/config.json
        # (config_io.embedding_section), which a repository cannot write, and a
        # symlinked cache dir is refused below.
        candidate = Path(cfg.cache_dir).expanduser()
        if not candidate.is_symlink():
            return candidate
    primary = venv_base / "embeddings_cache" / "models"
    if os.name == "nt" and len(str(primary)) > _WINDOWS_CACHE_DIR_HEADROOM:
        fallback = _fallback_cache_dir()
        try:
            fallback.mkdir(parents=True, exist_ok=True)
            import logging as _logging

            # 埋め込みは索引経路とプロンプト経路の両方から呼ばれる。インデクサの
            # 名前空間に出すと、プロンプト経路（skill_router.route のみ設定済み）
            # ではハンドラ不在で警告が捨てられる。
            _logging.getLogger("skill_router.embedding").warning(
                "embedding cache_dir %r is too deep for Windows MAX_PATH "
                "(len=%d > %d); falling back to %s. Set "
                "config.embedding.cache_dir explicitly to override.",
                str(primary),
                len(str(primary)),
                _WINDOWS_CACHE_DIR_HEADROOM,
                str(fallback),
            )
            return fallback
        except OSError:
            # Best effort: if even the fallback cannot be created we
            # return the primary anyway and let the caller fail open.
            pass
    return primary


def _cache_is_populated(cache_dir: Path) -> bool:
    """True when the ONNX cache holds a *complete* model.

    A download interrupted by the SessionStart timeout leaves ``.lock`` and
    ``*.incomplete`` files behind.  Treating those as "populated" would let the
    prompt path resume the download - exactly what require_cached exists to
    prevent - so a finished ``.onnx`` with no in-progress markers is required.
    """
    try:
        if not cache_dir.is_dir():
            return False
        onnx = list(cache_dir.rglob("*.onnx"))
        if not onnx:
            return False
        for marker in ("*.incomplete", "*.lock"):
            if any(cache_dir.rglob(marker)):
                return False
        return True
    except OSError:
        return False


def get_model(cfg: EmbeddingConfig, venv_base: Path,
              require_cached: bool = False) -> Any | None:
    """Return a loaded ``TextEmbedding`` or ``None`` on failure.

    ``venv_base`` locates the model cache; see :func:`_resolve_cache_dir` for
    why it must be the user-owned directory rather than ``<base>``.

    ``require_cached`` refuses to construct the model when the cache is still
    empty.  The prompt path passes it so a first-use download (~120 MB, no
    timeout of its own) can never block a user's prompt; SessionStart - which
    has a 360 s budget - performs the download instead.
    """
    if not is_sdk_available():
        return None
    cache_dir = _resolve_cache_dir(cfg, venv_base)
    key = (cfg.model, str(cache_dir))
    cached = _model_cache.get(key)
    if cached is not None:
        return cached
    if require_cached and not _cache_is_populated(cache_dir):
        return None
    try:
        cache_dir.mkdir(parents=True, exist_ok=True)
        instance = _TextEmbedding(  # type: ignore[misc]
            model_name=cfg.model,
            cache_dir=str(cache_dir),
        )
    except Exception:
        return None
    _model_cache[key] = instance
    return instance


# ---------------------------------------------------------------------------
# Embedding API
# ---------------------------------------------------------------------------


_MAX_INPUT_CHARS = 8192


def _sanitise_input(text: Any) -> str:
    """Reduce ``text`` to a safe string before sending to fastembed.

    - Non-strings are coerced to ``" "`` (placeholder, keeps batch shape).
    - NUL bytes are stripped (some ONNX runtimes have aborted on them).
    - Length is capped to :data:`_MAX_INPUT_CHARS` so a megabyte-sized
      paste cannot trigger huge tokenizer / inference memory spikes
      (security review L-8).
    """
    if not isinstance(text, str):
        return " "
    cleaned = text.replace("\x00", "").strip()
    if not cleaned:
        return " "
    if len(cleaned) > _MAX_INPUT_CHARS:
        cleaned = cleaned[:_MAX_INPUT_CHARS]
    return cleaned


def embed_many(model: Any, texts: list[str]) -> Any | None:
    """Vectorise a batch of texts.  Returns a 2-D numpy array or ``None``.

    The returned array has shape ``(len(texts), embedding_dim)``.  The
    fastembed API yields one vector per text, so we materialise the
    generator into a single ``np.stack`` for efficient downstream use.
    Inputs are sanitised by :func:`_sanitise_input` so non-strings,
    NULs and over-long pastes cannot crash the pipeline; callers that
    require strict skip-on-empty semantics must filter first.
    """
    if model is None or _np is None or not texts:
        return None
    cleaned = [_sanitise_input(t) for t in texts]
    try:
        vectors = list(model.embed(cleaned))
    except Exception:
        return None
    if not vectors:
        return None
    try:
        arr = _np.stack([_np.asarray(v, dtype=_np.float32) for v in vectors])
    except Exception:
        return None
    return _normalise_rows(arr)


def embed_one(model: Any, text: str) -> Any | None:
    """Vectorise a single text.  Returns a 1-D numpy array or ``None``."""
    out = embed_many(model, [text])
    if out is None:
        return None
    return out[0]


def cosine_similarity(query: Any, matrix: Any) -> Any | None:
    """Compute cosine similarity between ``query`` (1-D) and each row of ``matrix``.

    Assumes both inputs are L2-normalised (which ``_normalise_rows``
    guarantees).  Returns a 1-D array of length ``matrix.shape[0]`` or
    ``None`` when either argument is missing.
    """
    if query is None or matrix is None or _np is None:
        return None
    if matrix.ndim != 2 or query.ndim != 1:
        return None
    try:
        return matrix @ query
    except Exception:
        return None


def _normalise_rows(arr: Any) -> Any:
    """L2-normalise each row in-place safe (returns the same array).

    Pre-normalising lets cosine similarity reduce to a dot product,
    which is the hot path in :func:`cosine_similarity` and called for
    every UserPromptSubmit prompt.
    """
    if _np is None:
        return arr
    norms = _np.linalg.norm(arr, axis=1, keepdims=True)
    norms = _np.where(norms == 0.0, 1.0, norms)
    return arr / norms
