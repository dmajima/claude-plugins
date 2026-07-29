"""Build the routing index for skill-router (design v2 section 3.1).

Outputs (atomically replaced):
  <base>/index.json            machine-readable index, loaded by route.py
  <base>/inverted_index.json   keyword -> [skill_qualified_name, ...]
  <base>/index.log             append-only log
  <base>/error.log             append-only error log

The script is fail-open: any unrecoverable error logs and exits 0.

Schema support
--------------
``~/.claude/plugins/installed_plugins.json`` schema versions accepted by
this builder are listed in :data:`SUPPORTED_INSTALLED_SCHEMA`.  When a
new schema version ships, update **all** of the following together:

1. :data:`SUPPORTED_INSTALLED_SCHEMA` -- add the new integer to the
   ``frozenset``.
2. :func:`_resolve_install_path` -- ensure the new shape (e.g. extra
   wrappers around the per-key value) is recognised.  The current
   implementation already handles ``dict`` (v1) and ``list[dict]`` (v2);
   a v3 extension that adds, say, scope wrappers needs an additional
   branch here.
3. :func:`_count_installed_plugins` -- keep the totals consistent with
   how the new schema represents per-plugin entries.
4. ``references/scripts/tests/test_build_index.py`` -- add cases that
   round-trip the new shape.

Index files (``index.json`` / ``inverted_index.json``) are JSON-only by
design; the builder used to also emit ``index.pkl`` as a fast-load
cache, but that has been removed because :func:`pickle.load` against
attacker-controllable data is an RCE vector when ``<base>`` itself is
under user-writable storage.
"""
from __future__ import annotations

import json
import logging
import logging.handlers
import math
import os
import re
import socket
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import parse_evals  # noqa: E402  (sibling module, see design v2 section 3.2.6)
import config_io  # noqa: E402
import text_tokens  # noqa: E402

# Bound by :func:`_load_embedding_stack` on first use, not at import time.
embedding_client: Any = None
embedding_enrich: Any = None


def _load_embedding_stack() -> bool:
    """Import the embedding modules on first use.  True when they are usable.

    ``embedding_client`` pulls in numpy and fastembed - hundreds of milliseconds
    and ~50 MB of address space that the default configuration (embedding
    disabled) never uses.  Bound to module globals so callers (and tests) can
    reach them as ``build_index.embedding_enrich`` once loaded.
    """
    global embedding_client, embedding_enrich
    if embedding_client is not None:
        return True
    try:
        import embedding_client as _client
        import embedding_enrich as _enrich
    except Exception:  # pragma: no cover - fail-open
        return False
    embedding_client, embedding_enrich = _client, _enrich
    return True


SCHEMA_VERSION = 3
INVERTED_SCHEMA_VERSION = 1
MAX_POSTINGS_PER_KEYWORD = 50
# Versions of ~/.claude/plugins/installed_plugins.json that this builder
# understands.  Encountering an unknown version logs a warning but keeps
# scanning (fail-open, see module docstring).
SUPPORTED_INSTALLED_SCHEMA: frozenset[int] = frozenset({1, 2})

# Skip-phrase vocabularies.  Lifted from design v2 section 3.1.4 step 6.
_VERB_VOCAB: frozenset[str] = frozenset(
    {
        "変換",
        "生成",
        "出力",
        "作成",
        "修正",
        "レビュー",
        "削除",
        "更新",
        "確認",
        "実行",
        "公開",
        "起動",
    }
)
_NOUN_VOCAB: frozenset[str] = frozenset(
    {
        "HTML",
        "PDF",
        "PPTX",
        "PNG",
        "JPEG",
        "JPG",
        "SVG",
        "MD",
        "JSON",
        "YAML",
        "CSV",
        "DOCX",
        "XLSX",
    }
)


# ---------------------------------------------------------------------------
# Path resolution
# ---------------------------------------------------------------------------


# ``<base>`` の解決は config_io が所有する。`<venv-base>` と対の概念であり、
# 差分そのものがセキュリティ境界のため、2 つを別レイヤに置くと片方だけの変更で
# 境界が消える。ここでは再エクスポートし、モジュール属性としての差し替え
# （テストの patch）も従来どおり効くようにする。
resolve_base_dir = config_io.resolve_base_dir


_LOG_MAX_BYTES = 1_048_576  # 1 MiB per log file
_ERROR_LOG_MAX_BYTES = 1_048_576  # 1 MiB cap for the append-only error log
_LOG_BACKUP_COUNT = 3  # rotate to .1 / .2 / .3, then drop


def _setup_logger(base: Path) -> logging.Logger:
    base.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("skill_router.build_index")
    logger.setLevel(logging.INFO)
    if logger.handlers:
        return logger
    # Rotating handler (1 MiB x 3 backups = 4 MiB cap) prevents the log
    # from growing unboundedly across long-lived dev environments
    # (security review Suggestion / CWE-779).
    # route.py と同じ理由で、先に 0600 の実体を用意してからハンドラを開く。
    # route.py と同じく、ハンドラ生成の失敗で索引構築ごと止めない。
    try:
        try:
            config_io.open_append(base / "index.log").close()
        except OSError:
            pass
        handler = logging.handlers.RotatingFileHandler(
            base / "index.log",
            maxBytes=_LOG_MAX_BYTES,
            backupCount=_LOG_BACKUP_COUNT,
            encoding="utf-8",
        )
    except OSError:
        return logger
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    # 埋め込み側の警告（MAX_PATH フォールバック等）を index.log へ寄せる。
    # route.py 側も同じロガーを自分のファイルへ束ねるため、どちらの経路から
    # 呼ばれても警告が残る。
    embedding_logger = logging.getLogger("skill_router.embedding")
    if not embedding_logger.handlers:
        embedding_logger.setLevel(logging.INFO)
        embedding_logger.addHandler(handler)
    return logger


# ---------------------------------------------------------------------------
# Plugin enumeration
# ---------------------------------------------------------------------------


def _read_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None


_PLUGIN_KEY_RE = re.compile(r"^[A-Za-z0-9._@:-]{1,128}$")


def _enabled_plugin_keys(settings: Any) -> set[str]:
    """settings.json -> set of "plugin@marketplace" keys that are enabled."""
    out: set[str] = set()
    if not isinstance(settings, dict):
        return out
    enabled = settings.get("enabledPlugins") or {}
    if isinstance(enabled, dict):
        for key, val in enabled.items():
            if val:
                out.add(key)
    return out


def _iso8601_to_epoch(ts: Any) -> int:
    """Parse an ISO8601 string to epoch seconds, robust to TZ suffixes.

    Handles both ``Z`` and ``+HH:MM`` offsets.  Returns 0 for empty,
    malformed, or non-string values so missing timestamps sort below
    any real one in :func:`_entry_score`.
    """
    if not isinstance(ts, str) or not ts.strip():
        return 0
    candidate = ts.strip()
    if candidate.endswith("Z"):
        candidate = candidate[:-1] + "+00:00"
    try:
        return int(datetime.fromisoformat(candidate).timestamp())
    except (ValueError, TypeError):
        return 0


def _entry_score(entry: dict, expected_scope: str | None) -> tuple[int, int, int, str]:
    """Score an installed_plugins.json entry to pick the best match.

    Tuple ordering (descending priority via ``max`` natural order):
      1. scope match against ``expected_scope`` (1 if match, else 0)
      2. installPath existing as a directory on disk
      3. timestamp recency in epoch seconds (lastUpdated -> installedAt)
      4. installPath as deterministic tiebreaker
    """
    entry_scope = entry.get("scope")
    scope_match = 1 if expected_scope and entry_scope == expected_scope else 0

    raw_path = entry.get("installPath") or entry.get("path") or ""
    path_exists = 1 if raw_path and Path(raw_path).is_dir() else 0

    recency = _iso8601_to_epoch(entry.get("lastUpdated") or entry.get("installedAt"))

    return (scope_match, path_exists, recency, raw_path)


def _resolve_install_path(
    installed: Any, key: str, *, expected_scope: str | None = None
) -> Path | None:
    if not isinstance(installed, dict):
        return None
    plugin, _, marketplace = key.partition("@")
    plugins_section = installed.get("plugins") or installed
    if not isinstance(plugins_section, dict):
        return None
    entry = plugins_section.get(key) or plugins_section.get(plugin)
    if isinstance(entry, list):
        candidates = [e for e in entry if isinstance(e, dict)]
        if not candidates:
            return None
        entry = max(candidates, key=lambda e: _entry_score(e, expected_scope))
    if not isinstance(entry, dict):
        return None
    install_path = entry.get("installPath") or entry.get("path")
    if not install_path:
        return None
    candidate = Path(install_path)
    # Reject symlinks at any level on the way down to the install dir,
    # so a tampered ``installed_plugins.json`` cannot redirect skill
    # discovery into an attacker-controlled directory.  ``resolve()``
    # also canonicalises ``..`` segments.
    try:
        if candidate.is_symlink():
            return None
        resolved = candidate.resolve(strict=True)
    except OSError:
        return None
    return resolved if resolved.is_dir() else None


def _count_installed_plugins(installed: Any) -> int:
    """Count the total number of installed plugin entries.

    Handles both v1 (``dict`` per key) and v2 (``list[dict]`` per key)
    layouts of ``installed_plugins.json``; entries of unrecognised
    shapes are ignored rather than counted.
    """
    if not isinstance(installed, dict):
        return 0
    plugins = installed.get("plugins") or {}
    if not isinstance(plugins, dict):
        return 0
    total = 0
    for value in plugins.values():
        if isinstance(value, list):
            total += sum(1 for entry in value if isinstance(entry, dict))
        elif isinstance(value, dict):
            total += 1
    return total


# ---------------------------------------------------------------------------
# Skill metadata extraction
# ---------------------------------------------------------------------------


_FRONTMATTER_RE = re.compile(r"^---\n(.+?)\n---", re.DOTALL)
_USE_WHEN_RE = re.compile(r"Use\s+when\s+([^.]+)\.", re.IGNORECASE)
_SKIP_WHEN_RE = re.compile(r"SKIP\s+when\s+([^.]+)\.", re.IGNORECASE)
_TRIGGER_PHRASE_RE = re.compile(r"[「『]([^」』]+)[」』]|\"([^\"\n]{2,})\"")


def _parse_frontmatter(text: str) -> dict[str, str]:
    match = _FRONTMATTER_RE.match(text)
    if not match:
        return {}
    out: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        out[key.strip()] = val.strip().strip("'\"")
    return out


def _split_skip_phrases(text: str) -> tuple[list[str], list[str]]:
    if not text:
        return [], []
    tokens = re.findall(r"[A-Za-z]+|[一-鿿]{2,}|[ァ-ヺ]{2,}", text)
    upper = {t.upper() for t in tokens}
    verbs = sorted(t for t in tokens if t in _VERB_VOCAB)
    nouns = sorted({t.upper() for t in tokens if t.upper() in _NOUN_VOCAB} & upper)
    return verbs, list(nouns)


# トークナイザは text_tokens が所有する（router と同一の規則を使うため）。
# ここでは再エクスポートのみ行う。
extract_keywords = text_tokens.extract_keywords


def _extract_trigger_phrases(text: str) -> list[str]:
    out: list[str] = []
    for match in _TRIGGER_PHRASE_RE.finditer(text or ""):
        phrase = (match.group(1) or match.group(2) or "").strip()
        if phrase:
            out.append(phrase)
    # de-duplicate while preserving order
    return list(dict.fromkeys(out))


def _extract_skill_record(
    skill_md: Path,
    install_path: Path,
    qualified_name: str,
    plugin: str,
    marketplace: str,
    scope: str,
) -> dict[str, Any] | None:
    try:
        text = skill_md.read_text(encoding="utf-8")
    except OSError:
        return None
    fm = _parse_frontmatter(text)
    name = fm.get("name") or skill_md.parent.name
    description = fm.get("description", "")
    # Reuse the single match object instead of running each regex twice
    # (impl review Suggestion).
    use_match = _USE_WHEN_RE.search(description)
    use_when = use_match.group(1).strip() if use_match else ""
    skip_match = _SKIP_WHEN_RE.search(description)
    skip_when = skip_match.group(1).strip() if skip_match else ""
    skip_verbs, skip_nouns = _split_skip_phrases(skip_when)
    trigger_phrases = _extract_trigger_phrases(description)
    evals = parse_evals.parse_skill_evals(skill_md.parent)
    keywords = extract_keywords(
        name,
        description,
        " ".join(trigger_phrases),
        " ".join(c["prompt"] for c in evals),
    )
    return {
        "qualified_name": qualified_name,
        "skill_name": name,
        "plugin": plugin,
        "marketplace": marketplace,
        "scope": scope,
        "install_path": str(install_path),
        "skill_path": str(skill_md.parent.relative_to(install_path)).replace("\\", "/"),
        "description": description,
        "trigger_phrases": trigger_phrases,
        "use_when": use_when,
        "skip_when": skip_when,
        "skip_keywords_verb": skip_verbs,
        "skip_keywords_noun": skip_nouns,
        "evals": evals,
        "keywords": keywords,
        "extracted_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
    }


# ---------------------------------------------------------------------------
# Inverted index
# ---------------------------------------------------------------------------


def resolve_max_postings(base: Path) -> int:
    """``candidate_filter.max_postings_per_keyword`` from ``<base>/config.json``.

    A keyword pointing at more skills than this is treated as overgeneric and
    dropped from the inverted index.  Lowering it is the documented remedy for a
    bloated index (see the ``case-07`` / ``case-24`` diagnostics), which is why
    the key is read here rather than left as a constant.

    ``<base>`` can be supplied by a checked-out repository, so the value is
    clamped: 0 would drop every keyword and leave the router permanently
    silent, and a huge value would defeat the pruning that keeps scoring
    linear-ish.
    """
    try:
        section = config_io.load_raw_config(base).get("candidate_filter")
        if isinstance(section, dict):
            raw = section.get("max_postings_per_keyword",
                              MAX_POSTINGS_PER_KEYWORD)
            # JSON の `1e400` は float("inf") としてパースされ、int() が
            # OverflowError を送出する。捕捉しないと SessionStart の索引構築が
            # そのリポジトリで毎回失敗する。
            if isinstance(raw, float) and not math.isfinite(raw):
                return MAX_POSTINGS_PER_KEYWORD
            return max(1, min(500, int(raw)))
    except (TypeError, ValueError, OSError, OverflowError):
        pass
    return MAX_POSTINGS_PER_KEYWORD


def build_inverted_index(
    skills: list[dict[str, Any]],
    max_postings: int = MAX_POSTINGS_PER_KEYWORD,
) -> dict[str, Any]:
    raw: dict[str, list[str]] = {}
    for skill in skills:
        for kw in set(skill.get("keywords", []) + skill.get("trigger_phrases", [])):
            kw_norm = kw.strip().lower()
            if not kw_norm:
                continue
            raw.setdefault(kw_norm, []).append(skill["qualified_name"])

    overgeneric: list[str] = []
    pruned: dict[str, list[str]] = {}
    for kw, postings in raw.items():
        unique = sorted(set(postings))
        if len(unique) > max_postings:
            overgeneric.append(kw)
            continue
        pruned[kw] = unique

    return {
        "schema_version": INVERTED_SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "stats": {
            "total_keywords": len(pruned),
            "total_postings": sum(len(v) for v in pruned.values()),
            "skipped_overgeneric_keywords": len(overgeneric),
        },
        "index": pruned,
        "overgeneric": sorted(overgeneric),
    }


# ---------------------------------------------------------------------------
# Atomic write
# ---------------------------------------------------------------------------


def _atomic_write(path: Path, payload: bytes) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    # `<base>` への書き込みは config_io の 2 関数に一本化する（CLAUDE.md の
    # 不変条件）。素の write_bytes は O_NOFOLLOW を経由しないため、
    # drop_symlink との間に競合窓が残る。
    with config_io.open_write(tmp, binary=True) as fh:
        fh.write(payload)
    config_io.drop_symlink(path)
    os.replace(tmp, path)


def _write_outputs(
    base: Path, index: dict[str, Any], inverted: dict[str, Any]
) -> None:
    # `index.json` / `index.json.tmp` をディレクトリとして同梱されると
    # `_atomic_write` が OSError を送出する。ここで捕捉しないと build() の外へ
    # 抜け、索引が更新されないだけのはずが例外経路に落ちる。書けなければ
    # 前回の索引が据え置かれる（フェイルオープン）。
    for name, payload in (("index.json", index),
                          ("inverted_index.json", inverted)):
        try:
            _atomic_write(
                base / name,
                json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8"),
            )
        except OSError:
            logging.getLogger("skill_router.build_index").warning(
                "could not write %s; keeping the previous index", name)
    # Legacy index.pkl is removed if present.  See module docstring for
    # the security rationale (pickle.load is RCE-prone against
    # attacker-controllable <base>).
    legacy_pkl = base / "index.pkl"
    if legacy_pkl.exists():
        try:
            legacy_pkl.unlink()
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def build() -> dict[str, Any]:
    base = resolve_base_dir()
    logger = _setup_logger(base)
    started = time.perf_counter()

    home = Path(os.path.expanduser("~"))
    user_settings = _read_json(home / ".claude" / "settings.json")
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    project_settings_path = project_dir / ".claude" / "settings.json"
    project_settings = _read_json(project_settings_path)
    installed = _read_json(home / ".claude" / "plugins" / "installed_plugins.json")

    enabled_user = _enabled_plugin_keys(user_settings)
    # プロジェクト側 settings.json はリポジトリが供給しうる。キー名は
    # そのままログにも索引にも載るため、形式を検証してから採用する
    # （改行を含むキーでログ行を偽造されるのを防ぐ）。
    enabled_project = {
        key for key in _enabled_plugin_keys(project_settings)
        if _PLUGIN_KEY_RE.fullmatch(key)
    }
    enabled = enabled_user | enabled_project

    if isinstance(installed, dict):
        installed_schema = installed.get("version")
        if installed_schema is not None and installed_schema not in SUPPORTED_INSTALLED_SCHEMA:
            logger.warning(
                "unsupported installed_plugins schema=%s (supported=%s)",
                installed_schema,
                sorted(SUPPORTED_INSTALLED_SCHEMA),
            )

    skills: list[dict[str, Any]] = []
    skipped_plugins = 0
    for key in sorted(enabled):
        scope = "project" if key in enabled_project else "user"
        install_path = _resolve_install_path(installed, key, expected_scope=scope)
        if install_path is None:
            skipped_plugins += 1
            logger.warning("install path missing for %s",
                       config_io.sanitise_for_log(key))
            continue
        plugin, _, marketplace = key.partition("@")
        for skill_md in install_path.glob("skills/*/SKILL.md"):
            qualified = f"{plugin}:{skill_md.parent.name}"
            try:
                record = _extract_skill_record(
                    skill_md, install_path, qualified, plugin, marketplace, scope
                )
            except Exception:  # pragma: no cover - fail-open
                logger.exception("extract failed for %s", qualified)
                continue
            if record is not None:
                skills.append(record)

    # ------------------------------------------------------------------
    # Optional embedding-based skill vectorisation.
    #
    # Gated by ``config_io.embedding_section()`` - the single decision point
    # shared with venv_lifecycle (which builds the venv) and route.py (which
    # consumes the vectors), so the flag can never be on in one and off in
    # another.  It is read from <venv-base>, not from the repository-relative
    # base, so a clone cannot trigger the dependency install.
    # When disabled, missing SDK, or any failure, the helper returns
    # ``({}, None)`` and the heuristic-only behaviour is preserved.
    # ------------------------------------------------------------------
    embedding_section = config_io.embedding_section()
    embedding_opted_in = bool(embedding_section.get("enabled", False))
    embed_started = time.perf_counter()
    embed_qn_to_idx: dict[str, int] = {}
    embedding_model: str | None = None
    sdk_available = False
    # opt-in のときだけ numpy / fastembed を読み込む。無効時に import すると、
    # このモジュールを取り込む route.py（プロンプト経路）にも費用が乗る。
    if embedding_opted_in and _load_embedding_stack():
        embedding_cfg = embedding_client.EmbeddingConfig.from_dict(
            embedding_section)
        embedding_model = embedding_cfg.model
        try:
            embed_qn_to_idx, _matrix = embedding_enrich.ensure_skill_vectors(
                skills, base, embedding_cfg
            )
            sdk_available = embedding_client.is_sdk_available()
        except Exception:  # pragma: no cover - fail-open
            logger.exception(
                "embedding vectorisation failed; continuing with heuristic only")
            embed_qn_to_idx = {}
    embed_duration_ms = int((time.perf_counter() - embed_started) * 1000)

    duration_ms = int((time.perf_counter() - started) * 1000)
    embedding_active = (
        embedding_opted_in and sdk_available and bool(embed_qn_to_idx)
    )
    index = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds"),
        "python_version": list(sys.version_info[:3]),
        "host": socket.gethostname(),
        "scopes": {
            "user_settings_path": str(home / ".claude" / "settings.json"),
            "project_settings_path": str(project_settings_path),
            "project_dir": str(project_dir),
        },
        "stats": {
            "total_plugins_installed": _count_installed_plugins(installed),
            "total_plugins_enabled": len(enabled),
            "total_skills_indexed": len(skills),
            "skills_with_evals": sum(1 for s in skills if s["evals"]),
            "skipped_plugins": skipped_plugins,
            "scan_duration_ms": duration_ms,
            "embedding": {
                "enabled": bool(embedding_active),
                "model": embedding_model if embedding_active else None,
                "skills_vectorised": len(embed_qn_to_idx),
                "build_duration_ms": embed_duration_ms,
            },
        },
        "skills": skills,
    }
    inverted = build_inverted_index(skills, resolve_max_postings(base))
    _write_outputs(base, index, inverted)
    logger.info(
        "indexed skills=%d enabled=%d skipped=%d duration_ms=%d embedding=%s",
        len(skills),
        len(enabled),
        skipped_plugins,
        duration_ms,
        "on" if embedding_active else "off",
    )
    return index


def main() -> int:
    try:
        # Record "the venv was used" from the process that actually runs in it
        # (see venv_lifecycle.touch_last_used_if_active).  A no-op under the
        # system interpreter.
        try:
            import venv_lifecycle  # local import: keeps build()'s hot path lean

            venv_lifecycle.touch_last_used_if_active()
        except Exception:  # pragma: no cover - never block indexing
            pass
        build()
    except Exception:  # pragma: no cover - fail-open
        try:
            base = resolve_base_dir()
            base.mkdir(parents=True, exist_ok=True)
            import traceback

            import session_state  # local import: keeps build()'s hot path lean

            # Mask secret-shaped substrings (sk-/ghp_/Bearer/...) before
            # persisting the traceback; SessionStart-time exceptions can
            # capture environment values or prompt fragments
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
            # 追記は必ず config_io.open_append 経由。ここだけ素の open だった
            # ため、リポジトリが仕込んだリンク先へ traceback を書き込めた。
            with config_io.open_append(error_log) as fh:
                fh.write(f"=== {datetime.now(timezone.utc).isoformat()} ===\n")
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
