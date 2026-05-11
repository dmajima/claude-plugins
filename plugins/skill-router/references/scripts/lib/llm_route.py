"""Online LLM re-ranking for ambiguous mid-tier matches (Phase B).

When the heuristic produces a ``mid`` tier and the top1/top2 ratio is
small (typical of "two skills look equally plausible" cases), call the
LLM once with the top-N heuristic candidates and let it score
prompt-vs-skill fit on a 0..1 scale.  The fit score is then folded
back into the original heuristic score via:

    boosted_score = heuristic_score + score_boost * fit

Only the existing candidates are considered - the LLM never injects a
new skill that the candidate filter rejected, which keeps reasoning
about results bounded and makes the optimisation strictly additive.

Failure semantics
-----------------
Returns the input row list unchanged on every error path (missing
SDK, no API key, timeout, parse failure, empty response).  Callers
should treat the absence of mutation as the normal path.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import llm_client  # noqa: E402
import session_state  # noqa: E402  (re-uses mask_secrets)


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


_VALID_TRIGGER_TIERS: frozenset[str] = frozenset({"high", "mid", "low"})


@dataclass(frozen=True)
class OnlineConfig:
    enabled: bool = False
    trigger_tier: str = "mid"  # only re-rank this tier
    ratio_threshold: float = 1.5  # only when top1/top2 < this value
    max_candidates: int = 5
    timeout_sec: float = 5.0
    score_boost: float = 4.0  # max additive boost per candidate

    @classmethod
    def from_dict(cls, raw: Any) -> "OnlineConfig":
        if not isinstance(raw, dict):
            return cls()
        try:
            tier = str(raw.get("trigger_tier", "mid")).strip().lower() or "mid"
            if tier not in _VALID_TRIGGER_TIERS:
                tier = "mid"
            return cls(
                enabled=bool(raw.get("enabled", False)),
                trigger_tier=tier,
                # ratio_threshold <= 0 disables the re-rank gate (top1/top2 is
                # always >= 0), so clamp to a small positive epsilon.
                ratio_threshold=max(0.01, float(raw.get("ratio_threshold", 1.5))),
                max_candidates=max(1, int(raw.get("max_candidates", 5))),
                timeout_sec=max(0.5, float(raw.get("timeout_sec", 5.0))),
                # Negative score_boost would punish LLM-favoured candidates,
                # which is never the user's intent; clamp to non-negative.
                score_boost=max(0.0, float(raw.get("score_boost", 4.0))),
            )
        except (TypeError, ValueError):
            return cls()


# ---------------------------------------------------------------------------
# Prompt construction
# ---------------------------------------------------------------------------


_SYSTEM_PROMPT = (
    "You are the final arbiter for a Claude Code skill router. "
    "Given a user prompt and N candidate skills, decide how well each "
    "candidate matches the user's intent on a 0..1 scale.\n\n"
    "Output requirements:\n"
    "- Reply with a SINGLE JSON object only. No prose, no fences.\n"
    "- Schema: {\"matches\": [{\"skill\": string, \"fit\": number, \"reason\": string}]}\n"
    "- ``skill`` MUST be the candidate's qualified_name exactly as given.\n"
    "- ``fit`` is a number in [0, 1]. 1 = perfect match, 0 = unrelated.\n"
    "- Include every candidate exactly once. Do not invent skills.\n"
    "- ``reason`` is one short clause explaining the score.\n"
    "- Be strict: a vague topical link should score < 0.3."
)


def _candidate_block(skill: dict[str, Any]) -> str:
    parts = [
        f"qualified_name: {skill.get('qualified_name', '')}",
        f"description: {skill.get('description', '')}",
    ]
    if skill.get("use_when"):
        parts.append(f"use_when: {skill['use_when']}")
    if skill.get("skip_when"):
        parts.append(f"skip_when: {skill['skip_when']}")
    enrichment = skill.get("llm_enrichment") or {}
    if enrichment.get("task_label"):
        parts.append(f"task_label: {enrichment['task_label']}")
    return "\n".join(parts)


def _build_user_prompt(
    user_prompt: str, candidates: list[dict[str, Any]]
) -> str:
    blocks = []
    for idx, skill in enumerate(candidates, start=1):
        blocks.append(f"### Candidate {idx}\n{_candidate_block(skill)}")
    return (
        f"User prompt:\n{user_prompt}\n\n"
        + "\n\n".join(blocks)
        + "\n\nReturn JSON now."
    )


# ---------------------------------------------------------------------------
# Score application
# ---------------------------------------------------------------------------


def _coerce_fit(value: Any) -> float:
    try:
        f = float(value)
    except (TypeError, ValueError):
        return 0.0
    if f < 0.0:
        return 0.0
    if f > 1.0:
        return 1.0
    return f


def _apply_fits(
    rows: list[tuple[dict[str, Any], float, list[str]]],
    fits: dict[str, float],
    cfg: OnlineConfig,
) -> list[tuple[dict[str, Any], float, list[str]]]:
    boosted: list[tuple[dict[str, Any], float, list[str]]] = []
    for skill, score, reasons in rows:
        qn = skill.get("qualified_name", "")
        fit = fits.get(qn)
        if fit is None:
            boosted.append((skill, score, reasons))
            continue
        delta = cfg.score_boost * fit
        new_score = score + delta
        new_reasons = list(reasons) + [f"llm_fit={fit:.2f} (+{delta:.2f})"]
        boosted.append((skill, new_score, new_reasons))
    boosted.sort(key=lambda r: r[1], reverse=True)
    return boosted


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def should_invoke(
    tier: str, top1: float, top2: float, cfg: OnlineConfig
) -> bool:
    """Decide whether the LLM re-rank pass is warranted."""
    if not cfg.enabled:
        return False
    if tier != cfg.trigger_tier:
        return False
    if top1 <= 0:
        return False
    ratio = top1 / max(top2, 0.1)
    return ratio < cfg.ratio_threshold


def rerank(
    user_prompt: str,
    rows: list[tuple[dict[str, Any], float, list[str]]],
    base: Path,
    llm_cfg: llm_client.LLMConfig,
    online_cfg: OnlineConfig,
) -> list[tuple[dict[str, Any], float, list[str]]]:
    """Optionally re-rank ``rows`` using the LLM.  Falls back to ``rows``."""
    if not rows:
        return rows
    if not llm_cfg.enabled or not online_cfg.enabled:
        return rows
    if not llm_client.is_sdk_available():
        return rows
    api_key = llm_client.resolve_api_key(llm_cfg, plugin_base=base)
    if not api_key:
        return rows
    candidates = [r[0] for r in rows[: online_cfg.max_candidates]]
    if not candidates:
        return rows
    client = llm_client.get_client(llm_cfg, api_key)
    if client is None:
        return rows
    # Mask any secrets that may have been pasted into the user prompt
    # before sending it to the external API.  See security review M-2:
    # the user prompt is the most likely source of accidental
    # credential disclosure when Phase B is opted in.
    safe_prompt = session_state.mask_secrets(user_prompt)
    text = llm_client.call_messages(
        client,
        llm_cfg,
        system=_SYSTEM_PROMPT,
        user=_build_user_prompt(safe_prompt, candidates),
        max_tokens=600,
        cache_system=True,
        timeout_sec=online_cfg.timeout_sec,
    )
    payload = llm_client.parse_json_response(text)
    if not isinstance(payload, dict):
        return rows
    matches = payload.get("matches")
    if not isinstance(matches, list):
        return rows
    valid_qns = {c.get("qualified_name", "") for c in candidates}
    fits: dict[str, float] = {}
    for entry in matches:
        if not isinstance(entry, dict):
            continue
        qn = entry.get("skill")
        if not isinstance(qn, str) or qn not in valid_qns:
            continue
        fits[qn] = _coerce_fit(entry.get("fit"))
    if not fits:
        return rows
    return _apply_fits(rows, fits, online_cfg)
