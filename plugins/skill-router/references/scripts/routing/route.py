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
import logging.handlers
import math
import os
import re
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

# Budget clock starts before the sibling imports so that anything they pull in
# is counted.  Note the clock starts at module execution, so interpreter
# start-up (~0.45 s on Windows) is *not* included; it is a floor on the real
# elapsed time, not the exact value.
_PROCESS_STARTED = time.perf_counter()

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import config_io  # noqa: E402
import installed  # noqa: E402
import session_state  # noqa: E402
import text_tokens  # noqa: E402

# Bound by :func:`_load_embedding_stack` on first use, not at import time.
embedding_client: Any = None
embedding_enrich: Any = None
embedding_route: Any = None


def _load_embedding_stack() -> bool:
    """Import the embedding modules on first use.  True when they are usable.

    ``embedding_client`` pulls in numpy and fastembed, which is the dominant
    cost of this process when the venv is present.  Importing them at module
    scope made the soft budget below unenforceable - the cost was already paid
    before the check could run - and charged it to every prompt even though the
    default configuration never uses them.

    The modules are bound to module globals rather than kept local so callers
    (and tests) can reach them as ``route.embedding_enrich`` etc. once loaded.
    """
    global embedding_client, embedding_enrich, embedding_route
    if embedding_client is not None:
        return True
    try:
        import embedding_client as _client
        import embedding_enrich as _enrich
        import embedding_route as _route
    except Exception:  # pragma: no cover - fail-open
        return False
    embedding_client, embedding_enrich, embedding_route = _client, _enrich, _route
    return True


# ---------------------------------------------------------------------------
# Defaults (mirror design v2 section 4.5)
# ---------------------------------------------------------------------------

DEFAULT_CONFIG: dict[str, Any] = {
    # 3: 効かないキーだった tokenizer ブロックを削除（トークナイザの規則は
    #    text_tokens が固定で持つ。索引側と照合側で別々に設定を読むと、
    #    片方だけずれたときに逆引きが無音で外れるため）。
    "schema_version": 3,
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
        # Keep in sync with references/templates/config.default.json and the
        # README table; DefaultConfigTemplateTests pins them together.
        "high_ratio": 1.10,
        "mid_score": 4.0,
    },
    "candidate_filter": {
        "max_candidates_per_route": 50,
        # 索引構築側のキー。build_index.resolve_max_postings が読む。
        "max_postings_per_keyword": 50,
        "context_window": 3,
    },
}

# ``venv`` と ``embedding`` は <venv-base>/config.json が所有するため
# DEFAULT_CONFIG には含めない（<base> へ書き出すと効かない場所に効かない
# スイッチを配ることになる）。既定値は
# references/templates/config.venv-base.default.json を参照。


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------


_LOG_MAX_BYTES = 1_048_576  # 1 MiB per log file
_ERROR_LOG_MAX_BYTES = 1_048_576  # 1 MiB cap for the append-only error log
_LOG_BACKUP_COUNT = 3


def _setup_logger(base: Path) -> logging.Logger:
    logger = logging.getLogger("skill_router.route")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    base.mkdir(parents=True, exist_ok=True)
    # Rotating handler (1 MiB x 3 backups) caps long-running session
    # log growth (security review Suggestion / CWE-779).
    # RotatingFileHandler は umask 依存の権限（0644 相当）でファイルを作る。
    # ログには帯・スコア・推奨スキル名が載るため、先に 0600 の実体を用意して
    # おく（既存ファイルのモードを open_append は変更しない）。
    # ハンドラ生成は丸ごと保護する。`<base>/route.log` をディレクトリとして
    # 同梱されると RotatingFileHandler が OSError を送出し、ログが取れない
    # だけのはずが推奨機能ごと恒久停止する（git で同梱可能な DoS）。
    # ログ無しでもルーティングは続行させる。
    try:
        try:
            config_io.open_append(base / "route.log").close()
        except OSError:
            pass
        handler = logging.handlers.RotatingFileHandler(
            base / "route.log",
            maxBytes=_LOG_MAX_BYTES,
            backupCount=_LOG_BACKUP_COUNT,
            encoding="utf-8",
        )
    except OSError:
        return logger
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    # 埋め込み側（skill_router.embedding）の警告も同じファイルへ寄せる。
    # 独自の名前空間にしておかないと、索引経路のロガーへ出して
    # プロンプト経路では捨てられる、という取りこぼしが起きる。
    embedding_logger = logging.getLogger("skill_router.embedding")
    if not embedding_logger.handlers:
        embedding_logger.setLevel(logging.INFO)
        embedding_logger.addHandler(handler)
    return logger


def load_config(base: Path) -> dict[str, Any]:
    """Load `<base>/config.json` and deep-merge with :data:`DEFAULT_CONFIG`.

    Bootstrap behaviour: when the file is absent we serialise
    :data:`DEFAULT_CONFIG` so the operator has a starting point to
    edit.  The deep merge and raw read both live in
    :mod:`config_io` to avoid duplicating with build_index (review
    architect M-2).
    """
    path = base / "config.json"
    if not path.is_file():
        try:
            base.mkdir(parents=True, exist_ok=True)
            # `<base>` への書き込みは config_io の 2 関数に一本化する。
            with config_io.open_write(path) as fh:
                json.dump(DEFAULT_CONFIG, fh, ensure_ascii=False, indent=2)
        except OSError:
            pass
        return DEFAULT_CONFIG
    user_cfg = config_io.load_raw_config(base)
    if not user_cfg:
        return DEFAULT_CONFIG
    return _clamp_config(config_io.merge(DEFAULT_CONFIG, user_cfg))


def _clamp_config(cfg: dict[str, Any]) -> dict[str, Any]:
    """Keep threshold values inside a sane range.

    ``<base>/config.json`` can be supplied by a checked-out repository.  Zeroed
    or non-finite thresholds would make every prompt land in the ``high`` tier,
    turning the recommendation block into an instruction the agent trusts.
    Values outside the supported range fall back to the defaults rather than
    being honoured.
    """
    weights = cfg.get("weights")
    if isinstance(weights, dict):
        # 重みもリポジトリ供給の config.json から来うる。巨大値を入れられると
        # 閾値クランプを迂回して常に high 帯に到達させられる。
        for key, default in DEFAULT_CONFIG["weights"].items():
            try:
                # 309 桁以上の整数リテラルは int としてパースされ、float() が
                # OverflowError（ArithmeticError 派生）を送出する。
                # candidate_filter 側と捕捉範囲を揃える。
                value = float(weights.get(key, default))
            except (TypeError, ValueError, OverflowError):
                value = float(default)
            if not math.isfinite(value) or abs(value) > 10.0:
                value = float(default)
            weights[key] = value
    else:
        cfg["weights"] = dict(DEFAULT_CONFIG["weights"])

    # 候補絞込も同じ config.json から来る。文字列や 0 を入れられると
    # `_iter_tail` の比較や候補列のスライスが落ち、以降のプロンプトが
    # 恒久的に無音（推奨なし）になる。
    filters = cfg.get("candidate_filter")
    if not isinstance(filters, dict):
        cfg["candidate_filter"] = dict(DEFAULT_CONFIG["candidate_filter"])
    else:
        ceilings = {"max_candidates_per_route": 500,
                    "max_postings_per_keyword": 500,
                    "context_window": 50}
        for key, ceiling in ceilings.items():
            default = DEFAULT_CONFIG["candidate_filter"][key]
            raw = filters.get(key, default)
            try:
                # JSON の `1e999` は float('inf') になり、int() が
                # OverflowError（ArithmeticError 派生）を送出する。
                # これは下の except に含まれないため、捕捉しないと
                # route() の try の外まで抜けて以降のプロンプトが恒久的に
                # 推奨なしになる（build_index.resolve_max_postings と同型）。
                if isinstance(raw, float) and not math.isfinite(raw):
                    raise ValueError("non-finite")
                value = int(raw)
            except (TypeError, ValueError, OverflowError):
                value = default
            filters[key] = max(1, min(ceiling, value))

    limits = cfg.get("thresholds")
    if not isinstance(limits, dict):
        cfg["thresholds"] = dict(DEFAULT_CONFIG["thresholds"])
        return cfg
    defaults = DEFAULT_CONFIG["thresholds"]
    floors = {"high_score": 1.0, "mid_score": 0.5, "high_ratio": 1.0}
    for key, floor in floors.items():
        try:
            value = float(limits.get(key, defaults[key]))
        except (TypeError, ValueError, OverflowError):
            value = float(defaults[key])
        if not math.isfinite(value) or value < floor:
            value = float(defaults[key])
        limits[key] = value
    return cfg


# The index lives under a repository-relative base, so a clone can ship an
# arbitrarily large index.json.  Scoring is linear in its size, which would
# turn every prompt into a multi-second stall; refuse oversized files and fall
# back to the no-recommendation path.  4 MiB is roughly an order of magnitude
# above the observed size for a 120-skill install (309 KiB).
_MAX_INDEX_BYTES = 4_194_304  # 4 MiB

# Names that reach additionalContext must not be able to carry instructions.
_QUALIFIED_NAME_RE = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


def _oversized(path: Path) -> bool:
    try:
        return path.stat().st_size > _MAX_INDEX_BYTES
    except OSError:
        return False


def load_index(base: Path) -> dict[str, Any]:
    json_path = base / "index.json"
    if json_path.is_file() and not _oversized(json_path):
        try:
            with json_path.open("r", encoding="utf-8") as fh:
                return json.load(fh)
        except (OSError, json.JSONDecodeError):
            return {}
    return {}


def load_inverted(base: Path) -> dict[str, Any]:
    path = base / "inverted_index.json"
    if not path.is_file() or _oversized(path):
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
    tokens = text_tokens.extract_keywords(prompt)
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
    ratio = _calc_ratio(top1, top2)
    if top1 >= thresholds["high_score"] and ratio >= thresholds["high_ratio"]:
        return "high"
    if top1 >= thresholds["mid_score"]:
        return "mid"
    return "low"


def _format_high(skill: dict[str, Any], score: float, ratio: float, reasons: Iterable[str]) -> str:
    reason_block = "\n".join(f"  - {r}" for r in list(reasons)[:3])
    qn = skill["qualified_name"]
    return (
        f"[skill-router] 高適合スキルを検出（信頼度 {score:.1f}・上位差 {ratio:.2f}）\n"
        f"\n推奨: {qn}\n根拠:\n{reason_block}\n\n"
        f'Skill(skill: "{qn}") で起動してください。\n'
        "SKIP 条件に該当する場合のみ起動を見送ってください。"
    )


def _format_mid(rows: list[tuple[dict[str, Any], float, list[str]]], ratio: float) -> str:
    top = rows[0]
    qn = top[0]["qualified_name"]
    if ratio >= 1.15 or len(rows) < 2:
        reason_short = top[2][0] if top[2] else "score signals only"
        return (
            f"[skill-router] 推奨スキル候補（信頼度 {top[1]:.1f}）\n\n"
            f"推奨: {qn}\n根拠: {reason_short}\n\n"
            f'該当する場合は Skill(skill: "{qn}") での起動を検討してください。\n'
            "直接合致しなければ通常応答を継続して構いません。"
        )
    lines = [
        "[skill-router] 複数のスキル候補を検出:\n",
    ]
    for i, (skill, score, reasons) in enumerate(rows[:3], 1):
        reason_short = reasons[0] if reasons else "score signals only"
        lines.append(f"{i}. {skill['qualified_name']}（信頼度 {score:.1f}）: {reason_short}")
    lines.append(
        "\n複数候補があるため、AskUserQuestion でユーザーにどのスキルを使用するか確認してください。"
    )
    return "\n".join(lines)


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.stdout.flush()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


_MAX_PROMPT_CHARS = 65536  # 64 KiB; protects n-gram / tokenizer memory
# Soft budget measured from module execution (see _PROCESS_STARTED), covering
# the heuristic pass.  Checked *before* the embedding stack is imported, so
# exceeding it skips the numpy / fastembed import as well as the boost itself.
# It remains a pre-check rather than a deadline: once the boost is entered,
# model loading has no further limit beyond ``require_cached`` (which keeps a
# first-use download off this path).  On exceeding it the prompt is answered
# from the heuristic ranking rather than waiting on model I/O; the decision
# record carries ``over_budget: true`` so the skip is diagnosable.
_EMBEDDING_SOFT_BUDGET_SECONDS = 1.5

_FILTER_PREFIXES = ("<task-notification>", "<system-reminder>")


def _calc_ratio(top1: float, top2: float) -> float:
    return top1 / max(top2, 0.1)


def route(stdin_payload: dict[str, Any]) -> dict[str, Any] | None:
    # ゼロ幅文字を先に落としてから strip する。逆順だと "​ /cmd" の
    # 先頭空白が残り、スラッシュコマンドの除外に掛からない。
    prompt = (stdin_payload.get("prompt") or "").lstrip(
        "﻿​‌‍⁠").strip()
    if not prompt or prompt.startswith("/"):
        return None
    if prompt.startswith(_FILTER_PREFIXES):
        return None
    # Multi-megabyte prompts could blow up the n-gram extraction in
    # ``_eval_similarity`` and the token scan in ``extract_5w1h``.  The
    # bounded fastembed input caps embedding memory, but the heuristic
    # path is otherwise unbounded; reject up-front
    # (security review L-1, CWE-770).
    if len(prompt) > _MAX_PROMPT_CHARS:
        return None

    base = config_io.resolve_base_dir()
    logger = _setup_logger(base)
    config = load_config(base)

    # 履歴の記録はここで行う。以前は候補 0 件などの早期 return より後ろに
    # あったため、「ルーティングが成立したターンだけ」が context_window に
    # 載り、直近の話題が実際より古く見えていた。読み出しは追記より前に行う
    # （現在のプロンプトを自分自身の文脈に含めないため）。
    sid = session_state.resolve_session_id(stdin_payload)
    recent = session_state.tail_recent_prompts(
        base, sid, config["candidate_filter"]["context_window"])
    session_state.append_prompt(base, sid, stdin_payload)

    # ここから先の例外も決定行を残してから送出する。prompts.jsonl に行があって
    # route_decisions.jsonl に無い状態は「フックが打ち切られた」の証拠として
    # 診断に使われるため、内部例外が混ざるとタイムアウトとして誤分類される。
    try:
        return _route_ranked(prompt, base, sid, recent, config, logger)
    except Exception:
        _record_decision(base, sid, logger, {"tier": "error", "reason": "exception"})
        raise


def _record_decision(
    base: Path,
    sid: str,
    logger: logging.Logger,
    payload: dict[str, Any],
) -> None:
    """Append one decision row, stamped with the elapsed time.

    Every ``route()`` outcome - recommendation, skip and internal error - goes
    through here, which is what keeps ``route_decisions.jsonl`` one row per
    ``prompts.jsonl`` row.
    """
    elapsed = int((time.perf_counter() - _PROCESS_STARTED) * 1000)
    row = {"candidate": None, "embedding_used": False, **payload,
           "elapsed_ms": elapsed}
    session_state.append_route_decision(base, sid, row)
    if row["tier"] in ("skip", "error"):
        # route.log にも残す。「このプロンプトでは何も起きなかった」の理由を
        # 決定 jsonl だけに置くと、ログを見ている利用者からは無音に見える。
        logger.info("tier=%s reason=%s elapsed_ms=%d",
                    row["tier"], row.get("reason", "-"), elapsed)


def _route_ranked(
    prompt: str,
    base: Path,
    sid: str,
    recent: list[dict[str, Any]],
    config: dict[str, Any],
    logger: logging.Logger,
) -> dict[str, Any] | None:
    """Score the prompt and build the additionalContext block, if any.

    Split out of :func:`route` so the caller can guarantee a decision row is
    written even when this raises (see the ``try`` there).
    """
    weights = config["weights"]
    thresholds = config["thresholds"]
    cf = config["candidate_filter"]

    def _skip(reason: str) -> None:
        _record_decision(base, sid, logger, {"tier": "skip", "reason": reason})

    index = load_index(base)
    skills = index.get("skills", []) if isinstance(index, dict) else []
    if not skills:
        _skip("index_empty")
        return None
    # The index can be supplied by the repository (``<base>`` resolves there),
    # and the winning skill's qualified_name is rendered verbatim into
    # additionalContext - text the agent treats as trusted.  Only accept names
    # that cannot carry instructions: no newlines, no prose, bounded length.
    skills_by_qn = {
        s["qualified_name"]: s for s in skills
        if isinstance(s.get("qualified_name"), str)
        and _QUALIFIED_NAME_RE.fullmatch(s["qualified_name"])
    }

    inverted = load_inverted(base)
    five = extract_5w1h(prompt)

    candidates = select_candidates(five, inverted, skills_by_qn, cf["max_candidates_per_route"])
    if not candidates:
        _skip("no_candidates")
        return None

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
    # embedding ブロックは <venv-base> が所有する。<base>（リポジトリ相対に
    # なりうる）から読むと、有効判定とモデル設定の出所が割れて「venv は
    # 構築されたのにベクトル化が動かない」状態が生じる。
    embedding_section = config_io.embedding_section()
    embedding_used = False
    # The hook timeout is a ceiling for abnormal cases, not an operating
    # budget.  Model loading (or a first-use download) can block for far
    # longer than a prompt should wait, so the boost is skipped once the
    # heuristic pass has already spent the soft budget; the heuristic
    # ranking is returned instead of stalling the prompt.
    over_budget = ((time.perf_counter() - _PROCESS_STARTED)
                   > _EMBEDDING_SOFT_BUDGET_SECONDS)
    # 有効判定は素の dict で行い、numpy / fastembed を引き込む import は
    # そのあとに遅延実行する（既定構成では 1 度も走らない）。
    if (bool(embedding_section.get("enabled", False)) and rows
            and not over_budget and _load_embedding_stack()):
        embedding_cfg = embedding_client.EmbeddingConfig.from_dict(
            embedding_section)
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
                # モデルキャッシュは <venv-base>（ベクトルは <base>）。
                boosted = embedding_route.boost_rows(
                    prompt, rows, config_io.resolve_venv_base(),
                    embedding_cfg, qn_to_idx, matrix,
                )
            except Exception:  # pragma: no cover - fail-open
                boosted = rows
            if boosted is not rows:
                embedding_used = True
                rows = boosted

    top1 = rows[0][1] if rows else 0.0
    top2 = rows[1][1] if len(rows) > 1 else 0.0
    tier = determine_tier(top1, top2, thresholds)
    ratio = _calc_ratio(top1, top2)

    # 出力に載る行だけを実インストールと照合する。index.json はリポジトリ相対の
    # `<base>` から来うるため、自己申告の qualified_name をそのまま
    # additionalContext に流すと、命令文めいた文字列をエージェントに渡せる
    # （文字種の制限だけでは `plugin:ignore-all-prior-instructions-and-...` の
    # ようなハイフン区切りの英文が通ってしまう）。照合は出力対象の行に絞り、
    # プロンプト経路の追加 I/O を数件に抑える。
    dropped = 0
    if tier in ("high", "mid"):
        known = installed.installed_plugins()
        # high 帯でも 3 件見る。1 位だけを照合すると、実在しない候補が 1 位に
        # なっただけで（アンインストール直後で index が未再構築、等）実在する
        # 2 位以下ごと推奨が消える。
        emitted = rows[:3]
        verified = [r for r in emitted
                    if installed.is_installed(r[0], known=known)]
        if not verified:
            _skip("not_installed")
            return None
        dropped = len(emitted) - len(verified)
        rows = verified
        # 照合で行が入れ替わるため、記録・判定に使う値を再計算する。
        # そのままだと「top1=9.5 なのに candidate は別スコアの候補」という
        # 食い違いが診断ログに残り、切り分けの根拠として使えなくなる。
        top1 = rows[0][1]
        top2 = rows[1][1] if len(rows) > 1 else 0.0
        ratio = _calc_ratio(top1, top2)
        # 帯も再判定する。実在しない候補で水増しされた high をそのまま
        # 使うと、根拠の消えた「高適合」を提示することになる。
        tier = determine_tier(top1, top2, thresholds)

    if tier == "high":
        body = _format_high(rows[0][0], top1, ratio, rows[0][2])
    elif tier == "mid":
        body = _format_mid(rows, ratio)
    else:
        # low 帯では注入しない。候補が 1 件でもヒットすれば必ず本文が出るため、
        # 注入すると全ターンに「ミスマッチの可能性があります」というノイズを
        # 載せ続けることになる。判断材料は route.log / route_decisions.jsonl
        # に tier=low として残る。
        body = None

    # 経過時間と予算超過フラグを決定ログに残す。これが無いと
    # 「埋め込みが効かない」の原因が opt-out・キャッシュ未整備・予算超過の
    # どれなのかを、利用者が切り分けられない。
    # 本文の組み立て後に記録する。先に記録するとフォーマットが例外を送出した
    # 場合に error 行が追加され、1 プロンプト = 1 行の不変条件が崩れる。
    decision = {
        "tier": tier,
        "top1": top1,
        "top2": top2,
        "ratio": ratio,
        "candidate": rows[0][0]["qualified_name"] if rows else None,
        "alternatives": [r[0]["qualified_name"] for r in rows[1:3]],
        "embedding_used": embedding_used,
        "over_budget": over_budget,
    }
    if dropped:
        # 照合で落ちた件数。推奨が変わった理由の手掛かりとして残す。
        decision["not_installed_dropped"] = dropped
    _record_decision(base, sid, logger, decision)
    logger.info(
        "tier=%s top1=%.2f top2=%.2f ratio=%.2f embedding=%s over_budget=%s",
        tier,
        top1,
        top2,
        ratio,
        "on" if embedding_used else "off",
        over_budget,
    )

    if body is None:
        return None

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
        # Record "the venv was used" from the process that actually runs in it.
        # Keeping this out of ``venv_lifecycle python-bin`` leaves the
        # interpreter query side-effect free, so the SessionStart hook can order
        # its steps freely without silently disabling the TTL.
        try:
            import venv_lifecycle  # local import: keeps the cold path lean

            venv_lifecycle.touch_last_used_if_active()
        except Exception:  # pragma: no cover - never block routing
            pass
        try:
            stdin_payload = json.load(sys.stdin)
        except json.JSONDecodeError:
            return 0
        result = route(stdin_payload if isinstance(stdin_payload, dict) else {})
        if result is not None:
            _emit(result)
    except Exception:  # pragma: no cover - fail-open
        try:
            base = config_io.resolve_base_dir()
            base.mkdir(parents=True, exist_ok=True)
            # Mask secret-shaped substrings before persisting the traceback.
            # ``traceback.format_exc()`` can capture the offending prompt
            # fragment (e.g. ``ghp_...`` pasted by the user) so we route the
            # text through the same mask used by prompts.jsonl
            # (security review L-3, CWE-209).
            masked_tb = session_state.mask_secrets(traceback.format_exc())
            error_log = base / "error.log"
            # 恒常的に失敗する構成ではプロンプトごとに積み上がるため、
            # route.log / venv-construct.log と同様に上限を設ける。
            try:
                if error_log.exists() and error_log.stat().st_size > _ERROR_LOG_MAX_BYTES:
                    error_log.unlink()
            except OSError:
                pass
            with config_io.open_append(error_log) as fh:
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
