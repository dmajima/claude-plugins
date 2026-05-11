"""Offline LLM enrichment of indexed skills (Phase A).

For each skill record built by :mod:`build_index`, ask the configured
LLM (Anthropic Claude by default) to produce three signals that the
existing heuristics cannot derive from surface text:

- ``extra_keywords``: synonyms / domain words that should pull this
  skill into the candidate pool when users phrase requests
  differently.
- ``paraphrase_prompts``: short natural-language phrasings the user
  might actually type.  These extend ``evals`` for 3-gram similarity.
- ``task_label``: a coarse category label (Japanese OK).  Reserved for
  future scoring use; persisted today so callers can observe it.

Cache strategy
--------------
Per-skill ``content_hash`` (SHA256 over description / use_when /
skip_when / evals prompts) is stored in
``<base>/llm_cache/enrichment.json``.  When the hash is unchanged the
LLM is *not* called.  A per-run cap (``max_skills_per_run``) protects
the cost ceiling when a large fraction of skills changes
simultaneously.

Failure semantics
-----------------
Every public function returns an empty dict on failure (missing SDK,
missing API key, network error, malformed JSON).  Callers must treat
absence of enrichment as the normal "no-op" path so the plugin keeps
working with the heuristic flow alone.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import llm_client  # noqa: E402


CACHE_FILENAME = "enrichment.json"
CACHE_SCHEMA_VERSION = 1


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class EnrichConfig:
    enabled: bool = True  # gated by parent llm.enabled
    max_skills_per_run: int = 30
    max_keywords_per_skill: int = 15
    max_phrases_per_skill: int = 8
    weight_in_inverted_index: bool = True

    @classmethod
    def from_dict(cls, raw: Any) -> "EnrichConfig":
        if not isinstance(raw, dict):
            return cls()
        try:
            return cls(
                enabled=bool(raw.get("enabled", True)),
                max_skills_per_run=max(0, int(raw.get("max_skills_per_run", 30))),
                max_keywords_per_skill=max(
                    0, int(raw.get("max_keywords_per_skill", 15))
                ),
                max_phrases_per_skill=max(
                    0, int(raw.get("max_phrases_per_skill", 8))
                ),
                weight_in_inverted_index=bool(
                    raw.get("weight_in_inverted_index", True)
                ),
            )
        except (TypeError, ValueError):
            return cls()


# ---------------------------------------------------------------------------
# Hashing & cache I/O
# ---------------------------------------------------------------------------


def compute_content_hash(skill: dict[str, Any]) -> str:
    """Stable hash of the skill text inputs that drive enrichment.

    Includes only fields the LLM actually sees so cache invalidation
    happens iff the model would now produce a different answer.
    """
    parts: list[str] = [
        skill.get("qualified_name", "") or "",
        skill.get("description", "") or "",
        skill.get("use_when", "") or "",
        skill.get("skip_when", "") or "",
        " ".join(skill.get("trigger_phrases", []) or []),
    ]
    eval_prompts = [
        c.get("prompt", "") for c in (skill.get("evals") or []) if isinstance(c, dict)
    ]
    parts.append("\n".join(eval_prompts))
    digest_input = "\n---\n".join(parts).encode("utf-8", errors="replace")
    return hashlib.sha256(digest_input).hexdigest()


def cache_path(base: Path) -> Path:
    return base / "llm_cache" / CACHE_FILENAME


def _is_clean_cache_entry(entry: dict[str, Any]) -> bool:
    """Validate a cache entry on read.

    Defensive against M-3 in the security review: if some other
    process clobbers ``enrichment.json`` with a payload that bypassed
    ``_normalize_payload``, treat the entry as untrusted and refuse to
    promote its keywords / phrases into the routing index.
    """
    extra_keywords = entry.get("extra_keywords")
    if not isinstance(extra_keywords, list) or not all(
        isinstance(k, str) for k in extra_keywords
    ):
        return False
    phrases = entry.get("paraphrase_prompts")
    if not isinstance(phrases, list) or not all(isinstance(p, str) for p in phrases):
        return False
    label = entry.get("task_label", "")
    if not isinstance(label, str):
        return False
    if not isinstance(entry.get("content_hash"), str):
        return False
    if not isinstance(entry.get("model"), str):
        return False
    return True


def load_cache(base: Path) -> dict[str, dict[str, Any]]:
    """Load the enrichment cache.  Returns ``{}`` when missing/broken.

    Each surviving entry is also re-validated structurally so a
    tampered ``enrichment.json`` cannot inject malformed keyword lists
    into the in-memory routing index.  Length / character constraints
    are still enforced again later by ``apply_enrichment_to_skills``
    via the same normalisation path used at write time.
    """
    path = cache_path(base)
    if not path.is_file():
        return {}
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict):
        return {}
    entries = data.get("entries")
    if not isinstance(entries, dict):
        return {}
    out: dict[str, dict[str, Any]] = {}
    for qn, val in entries.items():
        if not (isinstance(qn, str) and isinstance(val, dict)):
            continue
        if not _is_clean_cache_entry(val):
            continue
        out[qn] = val
    return out


def save_cache(base: Path, entries: dict[str, dict[str, Any]]) -> None:
    """Atomically persist the enrichment cache.  Fail-open.

    Sets ``0o600`` permissions on POSIX after write so the cache is
    not accessible to other local users (security review M-3).  On
    Windows ``chmod`` is a best-effort no-op; ACL restriction would
    require pywin32 which we deliberately avoid.
    """
    path = cache_path(base)
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schema_version": CACHE_SCHEMA_VERSION,
            "generated_at": datetime.now(timezone.utc)
            .astimezone()
            .isoformat(timespec="seconds"),
            "entries": entries,
        }
        tmp = path.with_suffix(path.suffix + ".tmp")
        tmp.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        os.replace(tmp, path)
        if os.name == "posix":
            try:
                os.chmod(path, 0o600)
            except OSError:
                pass
    except OSError:
        return


# ---------------------------------------------------------------------------
# Prompt construction
# ---------------------------------------------------------------------------


_SYSTEM_PROMPT = (
    "You augment a Claude Code skill router. Given one skill's metadata, "
    "produce additional retrieval signals so users phrasing requests in "
    "different words still match the skill.\n\n"
    "Output requirements:\n"
    "- Reply with a SINGLE JSON object only. No prose, no fences.\n"
    "- Schema: {\n"
    '    "extra_keywords": string[],   // synonyms, domain terms, file types, related verbs/nouns\n'
    '    "paraphrase_prompts": string[], // natural utterances a user might actually type\n'
    '    "task_label": string          // short category label (any language)\n'
    "  }\n"
    "- Keep entries short (1-6 words each) and high precision.\n"
    "- Prefer the language the skill description is written in (Japanese skills => Japanese keywords/paraphrases).\n"
    "- Do NOT echo the skill name or trigger phrases already present.\n"
    "- Do NOT invent unrelated topics; stay strictly within what the skill actually does."
)


def _build_user_prompt(skill: dict[str, Any], cfg: EnrichConfig) -> str:
    eval_prompts = [
        c.get("prompt", "")
        for c in (skill.get("evals") or [])
        if isinstance(c, dict) and c.get("prompt")
    ][:8]
    parts: list[str] = [
        f"Skill qualified_name: {skill.get('qualified_name', '')}",
        f"Description: {skill.get('description', '')}",
    ]
    if skill.get("use_when"):
        parts.append(f"Use when: {skill['use_when']}")
    if skill.get("skip_when"):
        parts.append(f"Skip when: {skill['skip_when']}")
    if skill.get("trigger_phrases"):
        parts.append(
            "Existing trigger phrases: "
            + ", ".join(f'"{p}"' for p in skill["trigger_phrases"][:10])
        )
    if eval_prompts:
        parts.append("Existing eval prompts:\n- " + "\n- ".join(eval_prompts))
    parts.append(
        "\nReturn JSON now. "
        f"Limit extra_keywords to <= {cfg.max_keywords_per_skill}, "
        f"paraphrase_prompts to <= {cfg.max_phrases_per_skill}."
    )
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Response sanitisation
# ---------------------------------------------------------------------------


_FORBIDDEN_CHARS = set("\n\r\t\x00")


def _sanitise_string_list(
    raw: Any, limit: int, *, min_len: int = 1, max_len: int = 80
) -> list[str]:
    """Trim, dedupe and length-cap a list of strings.

    Drops entries containing control characters / newlines so a malicious
    skill cannot inject multi-line payloads via LLM enrichment (security
    review M-1 follow-up).
    """
    if not isinstance(raw, list):
        return []
    out: list[str] = []
    seen: set[str] = set()
    for item in raw:
        if not isinstance(item, str):
            continue
        cleaned = item.strip()
        if not cleaned or len(cleaned) < min_len or len(cleaned) > max_len:
            continue
        if any(ch in _FORBIDDEN_CHARS for ch in cleaned):
            continue
        key = cleaned.lower()
        if key in seen:
            continue
        seen.add(key)
        out.append(cleaned)
        if len(out) >= limit:
            break
    return out


def _sanitise_label(raw: Any) -> str:
    if not isinstance(raw, str):
        return ""
    cleaned = raw.strip().splitlines()[0] if raw.strip() else ""
    return cleaned[:40]


def _normalize_payload(payload: Any, cfg: EnrichConfig) -> dict[str, Any] | None:
    if not isinstance(payload, dict):
        return None
    extra_keywords = _sanitise_string_list(
        payload.get("extra_keywords"), cfg.max_keywords_per_skill, min_len=1, max_len=40
    )
    phrases = _sanitise_string_list(
        payload.get("paraphrase_prompts"),
        cfg.max_phrases_per_skill,
        min_len=2,
        max_len=160,
    )
    label = _sanitise_label(payload.get("task_label"))
    if not extra_keywords and not phrases and not label:
        return None
    return {
        "extra_keywords": extra_keywords,
        "paraphrase_prompts": phrases,
        "task_label": label,
    }


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def enrich_skills(
    skills: list[dict[str, Any]],
    base: Path,
    llm_cfg: llm_client.LLMConfig,
    enrich_cfg: EnrichConfig,
    *,
    now: float | None = None,
) -> dict[str, dict[str, Any]]:
    """Enrich skills offline.  Returns ``{qualified_name: enrichment_dict}``.

    Caller is responsible for merging the enrichment payload back into
    each skill record (see :func:`apply_enrichment_to_skills`).  This
    function only fetches / refreshes / persists; it does not mutate
    the input skill list.
    """
    if not skills or not enrich_cfg.enabled or not llm_cfg.enabled:
        return {}
    if not llm_client.is_sdk_available():
        return {}
    api_key = llm_client.resolve_api_key(llm_cfg, plugin_base=base)
    if not api_key:
        return {}

    cache = load_cache(base)
    pending: list[tuple[dict[str, Any], str]] = []
    for skill in skills:
        qn = skill.get("qualified_name")
        if not qn:
            continue
        digest = compute_content_hash(skill)
        cached = cache.get(qn)
        if (
            isinstance(cached, dict)
            and cached.get("content_hash") == digest
            and cached.get("model") == llm_cfg.model
        ):
            continue
        pending.append((skill, digest))

    if not pending:
        return _filter_for_qns(cache, [s["qualified_name"] for s in skills])

    pending = pending[: enrich_cfg.max_skills_per_run]
    client = llm_client.get_client(llm_cfg, api_key)
    if client is None:
        return _filter_for_qns(cache, [s["qualified_name"] for s in skills])

    timestamp_iso = (
        datetime.fromtimestamp(now, tz=timezone.utc).astimezone().isoformat(timespec="seconds")
        if now is not None
        else datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    )

    cache_dirty = False
    for skill, digest in pending:
        qn = skill["qualified_name"]
        user_prompt = _build_user_prompt(skill, enrich_cfg)
        text = llm_client.call_messages(
            client,
            llm_cfg,
            system=_SYSTEM_PROMPT,
            user=user_prompt,
            max_tokens=600,
            cache_system=True,
        )
        payload = llm_client.parse_json_response(text)
        normalized = _normalize_payload(payload, enrich_cfg)
        if normalized is None:
            continue
        cache[qn] = {
            "content_hash": digest,
            "model": llm_cfg.model,
            "generated_at": timestamp_iso,
            **normalized,
        }
        cache_dirty = True

    if cache_dirty:
        save_cache(base, cache)
    return _filter_for_qns(cache, [s["qualified_name"] for s in skills])


def apply_enrichment_to_skills(
    skills: list[dict[str, Any]],
    enrichment: dict[str, dict[str, Any]],
) -> None:
    """Mutate ``skills`` in place to attach enrichment fields.

    Adds the following fields to each matched skill:

    - ``llm_enrichment``: the raw enrichment record (for diagnostics)
    - extends ``keywords`` with ``extra_keywords`` (de-duplicated)
    - extends ``evals`` with synthetic ``paraphrase_prompts`` entries
      so eval-similarity scoring can pick them up
    """
    if not enrichment:
        return
    for skill in skills:
        qn = skill.get("qualified_name")
        if not qn or qn not in enrichment:
            continue
        record = enrichment[qn]
        skill["llm_enrichment"] = {
            "model": record.get("model"),
            "generated_at": record.get("generated_at"),
            "extra_keywords": list(record.get("extra_keywords", [])),
            "paraphrase_prompts": list(record.get("paraphrase_prompts", [])),
            "task_label": record.get("task_label", ""),
        }
        existing_kw_lower = {k.lower() for k in skill.get("keywords", [])}
        extra: list[str] = []
        for kw in record.get("extra_keywords", []):
            kw_clean = kw.strip()
            if not kw_clean:
                continue
            if kw_clean.lower() in existing_kw_lower:
                continue
            extra.append(kw_clean)
            existing_kw_lower.add(kw_clean.lower())
        if extra:
            skill["keywords"] = list(skill.get("keywords", [])) + extra
        synthetic_evals = [
            {"id": f"llm_paraphrase_{i}", "prompt": p, "kind": "llm_paraphrase", "expectations": []}
            for i, p in enumerate(record.get("paraphrase_prompts", []))
            if isinstance(p, str) and p.strip()
        ]
        if synthetic_evals:
            skill["evals"] = list(skill.get("evals", [])) + synthetic_evals


def _filter_for_qns(
    cache: dict[str, dict[str, Any]], qns: Iterable[str]
) -> dict[str, dict[str, Any]]:
    valid = set(qns)
    return {qn: rec for qn, rec in cache.items() if qn in valid}
