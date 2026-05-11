"""Anthropic Claude API client wrapper for skill-router LLM features.

A thin wrapper over the official ``anthropic`` Python SDK that:

- resolves the API key from an environment variable (first) or a
  ``credentials-manager``-style ``credentials.json`` (best-effort fallback).
- builds Messages API requests with optional system-prompt caching
  (``cache_control: ephemeral``) so repeated enrichment / routing calls
  benefit from Anthropic's prompt cache.
- returns ``None`` on every failure (fail-open) so the caller can quietly
  fall back to the existing heuristic flow.

The module imports ``anthropic`` lazily so the plugin still loads when
the SDK is unavailable (fresh install before the venv has been
constructed).  All public entry points behave as no-ops in that case.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

_ANTHROPIC_IMPORT_ERROR: Optional[Exception] = None
try:  # pragma: no cover - optional dependency
    import anthropic as _anthropic  # type: ignore
except Exception as exc:  # pragma: no cover - optional dependency
    _anthropic = None  # type: ignore
    _ANTHROPIC_IMPORT_ERROR = exc


DEFAULT_MODEL = "claude-haiku-4-5-20251001"
DEFAULT_API_KEY_ENV = "ANTHROPIC_API_KEY"
DEFAULT_TIMEOUT_SEC = 30.0
_CREDENTIAL_KEY_ALIASES: tuple[str, ...] = (
    "anthropic-api-key",
    "anthropic_api_key",
    "ANTHROPIC_API_KEY",
    "anthropic",
)
# Reject api_key_env names that don't look like a credential env var.
# Without this guard a tampered ``config.json`` could route ``PATH`` /
# ``HOME`` / ``AWS_SECRET_ACCESS_KEY`` through to the Anthropic API
# (the SDK happily attaches whatever string we pass as ``x-api-key``).
# We require an upper-snake-case identifier of bounded length, and
# additionally refuse a small block-list of obviously non-credential
# variables.  See security review H-1.
import re as _re

_API_KEY_ENV_PATTERN = _re.compile(r"^[A-Z][A-Z0-9_]{2,63}$")
_API_KEY_ENV_BLOCKLIST: frozenset[str] = frozenset(
    {
        "PATH",
        "HOME",
        "USERPROFILE",
        "USER",
        "USERNAME",
        "SHELL",
        "PWD",
        "OLDPWD",
        "TEMP",
        "TMP",
    }
)


def _validate_api_key_env(name: str) -> str:
    """Return ``name`` if it looks like an env var holding a secret, else default."""
    cleaned = (name or "").strip()
    if not cleaned:
        return DEFAULT_API_KEY_ENV
    if cleaned in _API_KEY_ENV_BLOCKLIST:
        return DEFAULT_API_KEY_ENV
    if not _API_KEY_ENV_PATTERN.match(cleaned):
        return DEFAULT_API_KEY_ENV
    return cleaned


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class LLMConfig:
    """Top-level ``llm`` block of ``config.json``.

    Defaults match ``references/templates/config.default.json``.  Any
    field can be overridden by user config; unknown keys are ignored.
    """

    enabled: bool = False
    provider: str = "anthropic"
    model: str = DEFAULT_MODEL
    api_key_env: str = DEFAULT_API_KEY_ENV
    request_timeout_sec: float = DEFAULT_TIMEOUT_SEC

    @classmethod
    def from_dict(cls, raw: Any) -> "LLMConfig":
        if not isinstance(raw, dict):
            return cls()
        try:
            return cls(
                enabled=bool(raw.get("enabled", False)),
                provider=str(raw.get("provider", "anthropic")),
                model=str(raw.get("model", DEFAULT_MODEL)) or DEFAULT_MODEL,
                api_key_env=_validate_api_key_env(
                    str(raw.get("api_key_env", DEFAULT_API_KEY_ENV))
                ),
                request_timeout_sec=float(
                    raw.get("request_timeout_sec", DEFAULT_TIMEOUT_SEC)
                ),
            )
        except (TypeError, ValueError):
            return cls()


# ---------------------------------------------------------------------------
# API key resolution
# ---------------------------------------------------------------------------


def _read_credentials_value(path: Path, alias_keys: tuple[str, ...]) -> str | None:
    try:
        with path.open("r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(data, dict):
        return None
    creds = data.get("credentials")
    if not isinstance(creds, dict):
        return None
    for alias in alias_keys:
        entry = creds.get(alias)
        if isinstance(entry, str) and entry.strip():
            return entry.strip()
        if isinstance(entry, dict):
            value = entry.get("value")
            if isinstance(value, str) and value.strip():
                return value.strip()
    return None


def _credentials_candidates(plugin_base: Path | None) -> list[Path]:
    """Return likely ``credentials.json`` paths produced by credentials-manager."""
    candidates: list[Path] = []
    if plugin_base is not None:
        candidates.append(
            plugin_base.parent / "credentials-manager" / "credentials.json"
        )
    home = Path(os.path.expanduser("~"))
    candidates.append(
        home / ".claude" / ".local" / "plugins" / "credentials-manager" / "credentials.json"
    )
    return candidates


def resolve_api_key(cfg: LLMConfig, plugin_base: Path | None = None) -> str | None:
    """Resolve the Anthropic API key.

    Priority:
      1. environment variable ``cfg.api_key_env``
      2. credentials-manager ``credentials.json`` (sibling plugin dir, then user home)
      3. ``None`` -> caller must short-circuit and skip the LLM call.
    """
    env_val = os.environ.get(cfg.api_key_env, "").strip()
    if env_val:
        return env_val
    for path in _credentials_candidates(plugin_base):
        value = _read_credentials_value(path, _CREDENTIAL_KEY_ALIASES)
        if value:
            return value
    return None


# ---------------------------------------------------------------------------
# Client construction
# ---------------------------------------------------------------------------


def is_sdk_available() -> bool:
    """Return ``True`` when the ``anthropic`` SDK is importable."""
    return _anthropic is not None


def get_client(cfg: LLMConfig, api_key: str) -> Any | None:
    """Construct an Anthropic client.  Returns ``None`` on failure."""
    if _anthropic is None or not api_key:
        return None
    try:
        return _anthropic.Anthropic(  # type: ignore[attr-defined]
            api_key=api_key,
            timeout=cfg.request_timeout_sec,
        )
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Messages API call
# ---------------------------------------------------------------------------


def _system_blocks(system: str, cache_system: bool) -> list[dict[str, Any]] | None:
    if not system:
        return None
    block: dict[str, Any] = {"type": "text", "text": system}
    if cache_system:
        block["cache_control"] = {"type": "ephemeral"}
    return [block]


def call_messages(
    client: Any,
    cfg: LLMConfig,
    *,
    system: str,
    user: str,
    max_tokens: int = 1024,
    cache_system: bool = True,
    timeout_sec: float | None = None,
) -> str | None:
    """Send a single-turn user message and return the concatenated text response.

    Returns ``None`` on any error.  ``timeout_sec`` overrides the
    client-default timeout for this single call (useful for routing).
    """
    if client is None or not user:
        return None
    kwargs: dict[str, Any] = {
        "model": cfg.model,
        "max_tokens": max(1, int(max_tokens)),
        "messages": [{"role": "user", "content": user}],
    }
    sys_blocks = _system_blocks(system, cache_system)
    if sys_blocks is not None:
        kwargs["system"] = sys_blocks
    if timeout_sec is not None:
        try:
            client_with_timeout = client.with_options(timeout=float(timeout_sec))
        except Exception:
            client_with_timeout = client
    else:
        client_with_timeout = client
    try:
        response = client_with_timeout.messages.create(**kwargs)
    except Exception:
        return None
    parts: list[str] = []
    for block in getattr(response, "content", None) or []:
        if getattr(block, "type", None) == "text":
            text = getattr(block, "text", "") or ""
            if text:
                parts.append(text)
    out = "\n".join(parts).strip()
    return out or None


_PARSE_INPUT_MAX_BYTES = 64 * 1024  # 64 KiB


def parse_json_response(text: str | None) -> Any:
    """Best-effort JSON parser for LLM output.

    Tolerates leading / trailing prose by extracting the first balanced
    JSON object or array.  Returns ``None`` when no parse succeeds so
    the caller can fall back to its no-op path.

    Inputs longer than ``_PARSE_INPUT_MAX_BYTES`` are rejected up-front
    to bound memory consumption (see security review L-1).
    """
    if not text:
        return None
    if len(text) > _PARSE_INPUT_MAX_BYTES:
        return None
    candidate = text.strip()
    try:
        return json.loads(candidate)
    except json.JSONDecodeError:
        pass
    # Extract the first balanced {...} or [...] block.
    for opener, closer in (("{", "}"), ("[", "]")):
        start = candidate.find(opener)
        if start == -1:
            continue
        depth = 0
        in_str = False
        esc = False
        for idx in range(start, len(candidate)):
            ch = candidate[idx]
            if in_str:
                if esc:
                    esc = False
                elif ch == "\\":
                    esc = True
                elif ch == '"':
                    in_str = False
                continue
            if ch == '"':
                in_str = True
                continue
            if ch == opener:
                depth += 1
            elif ch == closer:
                depth -= 1
                if depth == 0:
                    snippet = candidate[start : idx + 1]
                    try:
                        return json.loads(snippet)
                    except json.JSONDecodeError:
                        break
    return None
