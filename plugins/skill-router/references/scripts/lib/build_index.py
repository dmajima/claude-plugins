"""Build the routing index for skill-router (design v2 section 3.1).

Outputs (atomically replaced):
  <base>/index.json            human-readable, debug aid
  <base>/index.pkl             route.py fast-load cache
  <base>/inverted_index.json   keyword -> [skill_qualified_name, ...]
  <base>/index.log             append-only log
  <base>/error.log             append-only error log

The script is fail-open: any unrecoverable error logs and exits 0.
"""
from __future__ import annotations

import json
import logging
import os
import pickle
import re
import socket
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import parse_evals  # noqa: E402  (sibling module, see design v2 section 3.2.6)


SCHEMA_VERSION = 2
INVERTED_SCHEMA_VERSION = 1
MAX_POSTINGS_PER_KEYWORD = 50

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


def _project_root(start: Path) -> Path | None:
    """Walk up from `start` looking for .git, stopping at HOME boundary."""
    home = Path(os.path.expanduser("~")).resolve()
    cur = start.resolve()
    while True:
        if (cur / ".git").exists():
            return cur
        if cur == cur.parent or cur == home:
            return None
        cur = cur.parent


def resolve_base_dir() -> Path:
    """Resolution order documented in design v2 section 4.4."""
    plugin_data = os.environ.get("CLAUDE_PLUGIN_DATA", "").strip()
    if plugin_data:
        candidate = Path(plugin_data)
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            if os.access(candidate, os.W_OK):
                return candidate
        except OSError:
            pass

    project = _project_root(Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())))
    if project is not None:
        return project / ".claude" / ".local" / "plugins" / "skill-router"

    return Path(os.path.expanduser("~")) / ".claude" / ".local" / "plugins" / "skill-router"


def _setup_logger(base: Path) -> logging.Logger:
    base.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("skill_router.build_index")
    logger.setLevel(logging.INFO)
    if logger.handlers:
        return logger
    handler = logging.FileHandler(base / "index.log", encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
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


def _resolve_install_path(installed: Any, key: str) -> Path | None:
    if not isinstance(installed, dict):
        return None
    plugin, _, marketplace = key.partition("@")
    plugins_section = installed.get("plugins") or installed
    if not isinstance(plugins_section, dict):
        return None
    entry = plugins_section.get(key) or plugins_section.get(plugin)
    if not isinstance(entry, dict):
        return None
    install_path = entry.get("installPath") or entry.get("path")
    if not install_path:
        return None
    candidate = Path(install_path)
    return candidate if candidate.is_dir() else None


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


_KW_KANJI_RE = re.compile(r"[一-鿿]{2,}")
_KW_KATAKANA_RE = re.compile(r"[ァ-ヺー]{4,}")
_KW_ASCII_RE = re.compile(r"[A-Za-z][A-Za-z0-9_-]{1,}")
_STOPWORDS_EN: frozenset[str] = frozenset(
    {"the", "and", "for", "with", "this", "that", "from", "into", "use"}
)


def extract_keywords(*texts: str) -> list[str]:
    seen: dict[str, None] = {}
    for text in texts:
        if not text:
            continue
        for token in _KW_KANJI_RE.findall(text):
            seen.setdefault(token, None)
        for token in _KW_KATAKANA_RE.findall(text):
            seen.setdefault(token, None)
        for token in _KW_ASCII_RE.findall(text):
            lower = token.lower()
            if lower in _STOPWORDS_EN:
                continue
            seen.setdefault(lower, None)
    return list(seen)


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
    use_when = (_USE_WHEN_RE.search(description) or [None, ""])[1].strip() if _USE_WHEN_RE.search(description) else ""
    skip_when = (_SKIP_WHEN_RE.search(description) or [None, ""])[1].strip() if _SKIP_WHEN_RE.search(description) else ""
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


def build_inverted_index(skills: list[dict[str, Any]]) -> dict[str, Any]:
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
        if len(unique) > MAX_POSTINGS_PER_KEYWORD:
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
    tmp.write_bytes(payload)
    os.replace(tmp, path)


def _write_outputs(
    base: Path, index: dict[str, Any], inverted: dict[str, Any]
) -> None:
    _atomic_write(
        base / "index.json",
        json.dumps(index, ensure_ascii=False, indent=2).encode("utf-8"),
    )
    pickle_payload = {"schema_version": SCHEMA_VERSION, "python_version": list(sys.version_info[:3]), "index": index}
    _atomic_write(base / "index.pkl", pickle.dumps(pickle_payload))
    _atomic_write(
        base / "inverted_index.json",
        json.dumps(inverted, ensure_ascii=False, indent=2).encode("utf-8"),
    )


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
    enabled_project = _enabled_plugin_keys(project_settings)
    enabled = enabled_user | enabled_project

    skills: list[dict[str, Any]] = []
    skipped_plugins = 0
    for key in sorted(enabled):
        install_path = _resolve_install_path(installed, key)
        if install_path is None:
            skipped_plugins += 1
            logger.warning("install path missing for %s", key)
            continue
        plugin, _, marketplace = key.partition("@")
        scope = "project" if key in enabled_project else "user"
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

    duration_ms = int((time.perf_counter() - started) * 1000)
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
            "total_plugins_installed": len(installed.get("plugins", {})) if isinstance(installed, dict) else 0,
            "total_plugins_enabled": len(enabled),
            "total_skills_indexed": len(skills),
            "skills_with_evals": sum(1 for s in skills if s["evals"]),
            "skipped_plugins": skipped_plugins,
            "scan_duration_ms": duration_ms,
        },
        "skills": skills,
    }
    inverted = build_inverted_index(skills)
    _write_outputs(base, index, inverted)
    logger.info(
        "indexed skills=%d enabled=%d skipped=%d duration_ms=%d",
        len(skills),
        len(enabled),
        skipped_plugins,
        duration_ms,
    )
    return index


def main() -> int:
    try:
        build()
    except Exception:  # pragma: no cover - fail-open
        try:
            base = resolve_base_dir()
            base.mkdir(parents=True, exist_ok=True)
            with (base / "error.log").open("a", encoding="utf-8") as fh:
                import traceback

                fh.write(f"=== {datetime.now(timezone.utc).isoformat()} ===\n")
                traceback.print_exc(file=fh)
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    raise SystemExit(main())
