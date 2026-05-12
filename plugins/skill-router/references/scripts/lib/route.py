"""UserPromptSubmit router for skill-router (design v2 section 3.2).

Reads the hook stdin JSON, scores enabled skills against the user prompt,
and emits an additionalContext block when a high or mid tier match is
found.  Always exits 0 (fail-open).

Index loading is JSON-only.  The previous ``index.pkl`` fast-load path
has been removed because :func:`pickle.load` against a base directory
that may live on user-writable storage is an RCE vector.  See
``build_index.py`` module docstring for the full rationale.
"""
from __future__ import annotations

import json
import logging
import os
import re
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import build_index  # noqa: E402
import embedding_client  # noqa: E402
import embedding_enrich  # noqa: E402
import embedding_route  # noqa: E402
import session_state  # noqa: E402


# ---------------------------------------------------------------------------
# Defaults (mirror design v2 section 4.5)
# ---------------------------------------------------------------------------

DEFAULT_CONFIG: dict[str, Any] = {
    "schema_version": 2,
    "weights": {
        "keyword_overlap": 1.0,
        "trigger_phrase": 2.0,
        "eval_similarity": 3.0,
        "context_continuity": 1.5,
        "file_ext_match": 2.0,
        "skip_phrase_combo": -5.0,
        "skip_phrase_single": -1.0,
    },
    "thresholds": {
        "high_score": 8.0,
        "high_ratio": 1.25,
        "mid_score": 4.0,
    },
    "candidate_filter": {
        "max_candidates_per_route": 50,
        "max_postings_per_keyword": 50,
        "context_window": 3,
    },
    "tokenizer": {
        "min_kanji_length": 2,
        "min_katakana_length": 4,
    },
    "embedding": {
        "enabled": False,
        "model": embedding_client.DEFAULT_MODEL,
        "cache_dir": None,
        "weight": 3.0,
        "min_similarity": 0.3,
        "max_skills_per_run": 200,
    },
}


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


def _setup_logger(base: Path) -> logging.Logger:
    logger = logging.getLogger("skill_router.route")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    base.mkdir(parents=True, exist_ok=True)
    handler = logging.FileHandler(base / "route.log", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    return logger


def _merge(default: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    out = dict(default)
    for key, val in override.items():
        if key in out and isinstance(out[key], dict) and isinstance(val, dict):
            out[key] = _merge(out[key], val)
        else:
            out[key] = val
    return out


def load_config(base: Path) -> dict[str, Any]:
    path = base / "config.json"
    if not path.is_file():
        # Bootstrap default config so users can edit it without re-publishing.
        try:
            base.mkdir(parents=True, exist_ok=True)
            path.write_text(
                json.dumps(DEFAULT_CONFIG, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        except OSError:
            pass
        return DEFAULT_CONFIG
    try:
        with path.open("r", encoding="utf-8") as fh:
            user_cfg = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return DEFAULT_CONFIG
    return _merge(DEFAULT_CONFIG, user_cfg if isinstance(user_cfg, dict) else {})


def load_index(base: Path) -> dict[str, Any]:
    json_path = base / "index.json"
    if json_path.is_file():
        try:
            with json_path.open("r", encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, json.JSONDecodeError):
            return {}
    return {}


def load_inverted(base: Path) -> dict[str, Any]:
    path = base / "inverted_index.json"
    if not path.is_file():
        return {"index": {}, "overgeneric": []}
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {"index": {}, "overgeneric": []}


# ---------------------------------------------------------------------------
# Prompt analysis
# ---------------------------------------------------------------------------


_FILE_EXT_RE = re.compile(
    r"\.(html?|pdf|pptx?|docx?|xlsx?|csv|json|yml|yaml|md|txt|png|jpe?g|svg)\b",
    re.IGNORECASE,
)


def extract_5w1h(prompt: str) -> dict[str, Any]:
    tokens = build_index.extract_keywords(prompt)
    ext_match = _FILE_EXT_RE.search(prompt)
    file_ext = ext_match.group(1).lower() if ext_match else None
    # ``html?`` の正規表現は "htm" / "html" の両方をキャプチャするため、
    # ``htm`` だけ ``html`` に正規化する。以前の実装は
    # ``.replace("htm", "html")`` で "html" → "htmll" になるバグがあり、
    # 続く no-op ガード ``if file_ext == "html": file_ext = "html"`` も
    # 効いていなかった（review Low / 死コード指摘より発見）。
    if file_ext == "htm":
        file_ext = "html"
    return {
        "tokens": tokens,
        "file_ext": file_ext,
        "raw": prompt,
    }


def _ngrams(text: str, n: int = 3) -> set[str]:
    cleaned = re.sub(r"\s+", " ", text or "").strip().lower()
    if len(cleaned) < n:
        return {cleaned} if cleaned else set()
    return {cleaned[i : i + n] for i in range(len(cleaned) - n + 1)}


def _jaccard(a: set[str], b: set[str]) -> float:
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


# ---------------------------------------------------------------------------
# Candidate filter
# ---------------------------------------------------------------------------


def select_candidates(
    five: dict[str, Any],
    inverted: dict[str, Any],
    skills_by_qn: dict[str, dict[str, Any]],
    max_candidates: int,
) -> list[dict[str, Any]]:
    overgeneric = set(inverted.get("overgeneric", []))
    postings: dict[str, int] = {}
    for token in five["tokens"]:
        token_lower = token.lower()
        if token_lower in overgeneric:
            continue
        for qn in inverted.get("index", {}).get(token_lower, []):
            postings[qn] = postings.get(qn, 0) + 1

    if not postings and five.get("file_ext"):
        for qn in inverted.get("index", {}).get(five["file_ext"], []):
            postings[qn] = postings.get(qn, 0) + 1

    ranked = sorted(postings.items(), key=lambda kv: -kv[1])[:max_candidates]
    return [skills_by_qn[qn] for qn, _ in ranked if qn in skills_by_qn]


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------


def _keyword_overlap(prompt_tokens: list[str], skill_keywords: list[str]) -> int:
    overlap = len({t.lower() for t in prompt_tokens} & {k.lower() for k in skill_keywords})
    return min(overlap, 5)


def _trigger_phrase_partial(prompt: str, phrases: list[str]) -> int:
    if not prompt:
        return 0
    lowered = prompt.lower()
    hits = sum(1 for p in phrases if p and p.lower() in lowered)
    return min(hits, 3)


def _eval_similarity(prompt: str, evals: list[dict[str, Any]]) -> float:
    if not prompt or not evals:
        return 0.0
    p_grams = _ngrams(prompt)
    return max((_jaccard(p_grams, _ngrams(c.get("prompt", ""))) for c in evals), default=0.0)


def _context_continuity(
    prompt: str, skill: dict[str, Any], recent_prompts: list[dict[str, Any]]
) -> float:
    if not recent_prompts:
        return 0.0
    qn = skill.get("qualified_name", "")
    plugin = skill.get("plugin", "")
    hits = sum(
        1
        for record in recent_prompts
        if qn and qn in (record.get("prompt") or "")
        or (plugin and plugin in (record.get("prompt") or ""))
    )
    return min(hits / max(len(recent_prompts), 1), 1.0)


def _file_ext_match(file_ext: str | None, skill_keywords: list[str]) -> int:
    if not file_ext:
        return 0
    haystack = {k.lower() for k in skill_keywords}
    return 1 if file_ext.lower() in haystack else 0


def _skip_phrase_signals(
    tokens: list[str], skill: dict[str, Any]
) -> tuple[int, int]:
    token_set = {t for t in tokens}
    upper_set = {t.upper() for t in tokens}
    verb_hit = bool(token_set & set(skill.get("skip_keywords_verb", [])))
    noun_hit = bool(upper_set & {n.upper() for n in skill.get("skip_keywords_noun", [])})
    if verb_hit and noun_hit:
        return 1, 0
    if verb_hit or noun_hit:
        return 0, 1
    return 0, 0


def score_skill(
    five: dict[str, Any],
    skill: dict[str, Any],
    recent: list[dict[str, Any]],
    weights: dict[str, float],
) -> tuple[float, list[str]]:
    reasons: list[str] = []
    contributions: list[tuple[str, float]] = []

    kw = _keyword_overlap(five["tokens"], skill.get("keywords", []))
    contributions.append(("keyword_overlap", kw * weights["keyword_overlap"]))

    tr = _trigger_phrase_partial(five["raw"], skill.get("trigger_phrases", []))
    contributions.append(("trigger_phrase", tr * weights["trigger_phrase"]))

    ev = _eval_similarity(five["raw"], skill.get("evals", []))
    contributions.append(("eval_similarity", ev * weights["eval_similarity"]))

    ctx = _context_continuity(five["raw"], skill, recent)
    contributions.append(("context_continuity", ctx * weights["context_continuity"]))

    fe = _file_ext_match(five.get("file_ext"), skill.get("keywords", []))
    contributions.append(("file_ext_match", fe * weights["file_ext_match"]))

    combo, single = _skip_phrase_signals(five["tokens"], skill)
    contributions.append(("skip_phrase_combo", combo * weights["skip_phrase_combo"]))
    contributions.append(("skip_phrase_single", single * weights["skip_phrase_single"]))

    total = sum(value for _, value in contributions)
    for label, value in contributions:
        if value:
            reasons.append(f"{label}={value:+.2f}")
    return total, reasons


# ---------------------------------------------------------------------------
# Tier + emission
# ---------------------------------------------------------------------------


def determine_tier(
    top1: float, top2: float, thresholds: dict[str, float]
) -> str:
    if (
        top1 >= thresholds["high_score"]
        and top1 / max(top2, 0.1) >= thresholds["high_ratio"]
    ):
        return "high"
    if top1 >= thresholds["mid_score"]:
        return "mid"
    return "low"


def _format_high(skill: dict[str, Any], score: float, ratio: float, reasons: Iterable[str]) -> str:
    reason_block = "\n".join(f"  - {r}" for r in list(reasons)[:3])
    return (
        f"[skill-router] 高適合スキルを検出（信頼度 {score:.1f}・上位差 {ratio:.2f}）\n"
        f"\n推奨: {skill['qualified_name']}\n根拠:\n{reason_block}\n\n"
        "skill-invocation-priority.md に従い、Skill ツール経由で起動してください。\n"
        "SKIP 条件に該当する場合のみ起動を見送ってください。"
    )


def _format_mid(rows: list[tuple[dict[str, Any], float, list[str]]]) -> str:
    lines = ["[skill-router] 関連する可能性のあるスキル候補（参考情報）:\n"]
    for skill, score, reasons in rows[:3]:
        reason_short = reasons[0] if reasons else "score signals only"
        lines.append(f"- {skill['qualified_name']}（信頼度 {score:.1f}）: {reason_short}")
    lines.append("\n該当があれば検討してください。直接合致しなければ通常応答を継続して構いません。")
    return "\n".join(lines)


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.stdout.flush()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


_MAX_PROMPT_CHARS = 65536  # 64 KiB; protects n-gram / tokenizer memory


def route(stdin_payload: dict[str, Any]) -> dict[str, Any] | None:
    prompt = (stdin_payload.get("prompt") or "").strip()
    if not prompt or prompt.startswith("/"):
        return None
    # Multi-megabyte prompts could blow up the n-gram extraction in
    # ``_eval_similarity`` and the token scan in ``extract_5w1h``.  The
    # 10s UserPromptSubmit budget plus the bounded fastembed input
    # already cap embedding memory, but the heuristic path is otherwise
    # unbounded; reject up-front (security review L-1, CWE-770).
    if len(prompt) > _MAX_PROMPT_CHARS:
        return None

    base = build_index.resolve_base_dir()
    logger = _setup_logger(base)
    config = load_config(base)
    weights = config["weights"]
    thresholds = config["thresholds"]
    cf = config["candidate_filter"]

    index = load_index(base)
    skills = index.get("skills", []) if isinstance(index, dict) else []
    if not skills:
        return None
    skills_by_qn = {s["qualified_name"]: s for s in skills if s.get("qualified_name")}

    inverted = load_inverted(base)
    five = extract_5w1h(prompt)

    candidates = select_candidates(five, inverted, skills_by_qn, cf["max_candidates_per_route"])
    if not candidates:
        return None

    sid = session_state.resolve_session_id(stdin_payload)
    recent = session_state.tail_recent_prompts(base, sid, cf["context_window"])
    session_state.append_prompt(base, sid, stdin_payload)

    rows: list[tuple[dict[str, Any], float, list[str]]] = []
    for skill in candidates:
        score, reasons = score_skill(five, skill, recent, weights)
        rows.append((skill, score, reasons))
    rows.sort(key=lambda r: r[1], reverse=True)

    # ------------------------------------------------------------------
    # Optional embedding-based boost (v0.4+).
    #
    # Loads the SessionStart-built vector cache and applies a cosine
    # similarity boost.  When ``embedding.enabled = false`` or the
    # cache is missing, ``boost_rows`` returns the input unchanged.
    # ------------------------------------------------------------------
    embedding_section = config.get("embedding")
    if not isinstance(embedding_section, dict):
        embedding_section = {}
    embedding_cfg = embedding_client.EmbeddingConfig.from_dict(embedding_section)
    embedding_used = False
    if embedding_cfg.enabled and rows:
        try:
            manifest = embedding_enrich.load_manifest(base)
            qn_to_idx = {
                qn: entry["idx"]
                for qn, entry in manifest.items()
                if isinstance(entry, dict)
                and isinstance(entry.get("idx"), int)
                and entry["idx"] >= 0
            }
            expected_sha = embedding_enrich.load_vectors_sha256_from_manifest(base)
            matrix = embedding_enrich.load_vectors(base, expected_sha256=expected_sha)
        except Exception:  # pragma: no cover - fail-open
            qn_to_idx, matrix = {}, None
        if qn_to_idx and matrix is not None:
            try:
                boosted = embedding_route.boost_rows(
                    prompt, rows, base, embedding_cfg, qn_to_idx, matrix
                )
            except Exception:  # pragma: no cover - fail-open
                boosted = rows
            if boosted is not rows:
                embedding_used = True
                rows = boosted

    top1 = rows[0][1] if rows else 0.0
    top2 = rows[1][1] if len(rows) > 1 else 0.0
    tier = determine_tier(top1, top2, thresholds)
    ratio = top1 / max(top2, 0.1)

    decision = {
        "tier": tier,
        "top1": top1,
        "top2": top2,
        "ratio": ratio,
        "candidate": rows[0][0]["qualified_name"] if rows else None,
        "alternatives": [r[0]["qualified_name"] for r in rows[1:3]],
        "embedding_used": embedding_used,
    }
    session_state.append_route_decision(base, sid, decision)
    logger.info(
        "tier=%s top1=%.2f top2=%.2f ratio=%.2f embedding=%s",
        tier,
        top1,
        top2,
        ratio,
        "on" if embedding_used else "off",
    )

    if tier == "low":
        return None

    if tier == "high":
        body = _format_high(rows[0][0], top1, ratio, rows[0][2])
    else:
        body = _format_mid(rows)

    return {
        "continue": True,
        "suppressOutput": True,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": body,
        },
    }


def main() -> int:
    try:
        try:
            stdin_payload = json.load(sys.stdin)
        except json.JSONDecodeError:
            return 0
        result = route(stdin_payload if isinstance(stdin_payload, dict) else {})
        if result is not None:
            _emit(result)
    except Exception:  # pragma: no cover - fail-open
        try:
            base = build_index.resolve_base_dir()
            base.mkdir(parents=True, exist_ok=True)
            # Mask secret-shaped substrings before persisting the traceback.
            # ``traceback.format_exc()`` can capture the offending prompt
            # fragment (e.g. ``ghp_...`` pasted by the user) so we route the
            # text through the same mask used by prompts.jsonl
            # (security review L-3, CWE-209).
            masked_tb = session_state.mask_secrets(traceback.format_exc())
            with (base / "error.log").open("a", encoding="utf-8") as fh:
                fh.write(f"=== {datetime.now(timezone.utc).isoformat()} route ===\n")
                fh.write(masked_tb)
                if not masked_tb.endswith("\n"):
                    fh.write("\n")
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
