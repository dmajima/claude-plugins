"""Unit tests for the ``llm_client`` wrapper.

These tests deliberately avoid touching the real Anthropic API; the
SDK is treated as an optional import and a fake module is injected
when behaviour-around-the-network needs to be verified.

Run from the repository root::

    python -m unittest plugins/skill-router/tests/test_llm_client.py
"""
from __future__ import annotations

import json
import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

_LIB = (
    Path(__file__).resolve().parent.parent
    / "references"
    / "scripts"
    / "lib"
)
sys.path.insert(0, str(_LIB))

import llm_client  # noqa: E402


class LLMConfigFromDictTests(unittest.TestCase):
    def test_defaults_when_input_not_dict(self) -> None:
        cfg = llm_client.LLMConfig.from_dict("not-a-dict")
        self.assertFalse(cfg.enabled)
        self.assertEqual(cfg.model, llm_client.DEFAULT_MODEL)

    def test_overrides_applied(self) -> None:
        cfg = llm_client.LLMConfig.from_dict(
            {
                "enabled": True,
                "model": "claude-test-1",
                "api_key_env": "MY_ENV_VAR",
                "request_timeout_sec": 7,
            }
        )
        self.assertTrue(cfg.enabled)
        self.assertEqual(cfg.model, "claude-test-1")
        self.assertEqual(cfg.api_key_env, "MY_ENV_VAR")
        self.assertEqual(cfg.request_timeout_sec, 7.0)

    def test_invalid_timeout_falls_back_to_default(self) -> None:
        cfg = llm_client.LLMConfig.from_dict(
            {"enabled": True, "request_timeout_sec": "not-a-number"}
        )
        # Falls all the way back to default constructor (None) because
        # ValueError is caught at the top.
        self.assertEqual(cfg.request_timeout_sec, llm_client.DEFAULT_TIMEOUT_SEC)
        self.assertFalse(cfg.enabled)


class ResolveApiKeyTests(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.base = Path(self._tmp.name) / "skill-router"
        self.base.mkdir()

    def test_env_var_wins(self) -> None:
        cfg = llm_client.LLMConfig(api_key_env="ROUTER_TEST_API_KEY")
        with mock.patch.dict(os.environ, {"ROUTER_TEST_API_KEY": "  abc-123  "}):
            self.assertEqual(
                llm_client.resolve_api_key(cfg, plugin_base=self.base), "abc-123"
            )

    def test_credentials_json_string_value(self) -> None:
        cfg = llm_client.LLMConfig(api_key_env="ABSENT_VAR_FOR_TEST")
        creds_dir = self.base.parent / "credentials-manager"
        creds_dir.mkdir()
        (creds_dir / "credentials.json").write_text(
            json.dumps({"credentials": {"anthropic-api-key": "from-string"}}),
            encoding="utf-8",
        )
        with mock.patch.dict(os.environ, {}, clear=False):
            os.environ.pop("ABSENT_VAR_FOR_TEST", None)
            self.assertEqual(
                llm_client.resolve_api_key(cfg, plugin_base=self.base),
                "from-string",
            )

    def test_credentials_json_dict_value(self) -> None:
        cfg = llm_client.LLMConfig(api_key_env="ABSENT_VAR_FOR_TEST_2")
        creds_dir = self.base.parent / "credentials-manager"
        creds_dir.mkdir()
        (creds_dir / "credentials.json").write_text(
            json.dumps(
                {
                    "credentials": {
                        "ANTHROPIC_API_KEY": {"value": "from-dict-form", "scope": "user"}
                    }
                }
            ),
            encoding="utf-8",
        )
        os.environ.pop("ABSENT_VAR_FOR_TEST_2", None)
        self.assertEqual(
            llm_client.resolve_api_key(cfg, plugin_base=self.base),
            "from-dict-form",
        )

    def test_missing_returns_none(self) -> None:
        cfg = llm_client.LLMConfig(api_key_env="ABSENT_VAR_FOR_TEST_3")
        os.environ.pop("ABSENT_VAR_FOR_TEST_3", None)
        # Don't pass plugin_base so only the (likely non-existent) home
        # path is consulted; assume there is no real credentials file.
        with mock.patch.object(
            llm_client, "_credentials_candidates", return_value=[]
        ):
            self.assertIsNone(llm_client.resolve_api_key(cfg, plugin_base=None))


class ParseJsonResponseTests(unittest.TestCase):
    def test_pure_json_object_parsed(self) -> None:
        self.assertEqual(
            llm_client.parse_json_response('{"a": 1, "b": [2, 3]}'),
            {"a": 1, "b": [2, 3]},
        )

    def test_pure_json_array_parsed(self) -> None:
        self.assertEqual(llm_client.parse_json_response("[1, 2, 3]"), [1, 2, 3])

    def test_json_inside_prose_extracted(self) -> None:
        text = 'Here you go:\n```\n{"x": "y"}\n```\nDone.'
        self.assertEqual(llm_client.parse_json_response(text), {"x": "y"})

    def test_garbage_returns_none(self) -> None:
        self.assertIsNone(llm_client.parse_json_response("nothing here"))

    def test_empty_returns_none(self) -> None:
        self.assertIsNone(llm_client.parse_json_response(""))
        self.assertIsNone(llm_client.parse_json_response(None))

    def test_string_with_braces_inside_string_handled(self) -> None:
        # Make sure the brace-balancing scanner doesn't get confused by
        # braces *inside* a JSON string literal.
        text = '{"k": "value with } brace"}'
        self.assertEqual(
            llm_client.parse_json_response(text), {"k": "value with } brace"}
        )


class _FakeBlock:
    def __init__(self, text: str) -> None:
        self.type = "text"
        self.text = text


class _FakeResponse:
    def __init__(self, text: str) -> None:
        self.content = [_FakeBlock(text)]


class _FakeMessages:
    def __init__(self, response: _FakeResponse | Exception) -> None:
        self._response = response
        self.calls: list[dict] = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if isinstance(self._response, Exception):
            raise self._response
        return self._response


class _FakeClient:
    def __init__(self, response: _FakeResponse | Exception) -> None:
        self.messages = _FakeMessages(response)
        self.timeout_set: float | None = None

    def with_options(self, *, timeout: float):
        new = _FakeClient.__new__(_FakeClient)
        new.messages = self.messages
        new.timeout_set = float(timeout)
        return new


class CallMessagesTests(unittest.TestCase):
    def test_returns_text_when_response_is_text_block(self) -> None:
        client = _FakeClient(_FakeResponse("hello world"))
        cfg = llm_client.LLMConfig(model="claude-x")
        out = llm_client.call_messages(client, cfg, system="sys", user="hi")
        self.assertEqual(out, "hello world")
        sent = client.messages.calls[0]
        self.assertEqual(sent["model"], "claude-x")
        self.assertIn("system", sent)
        # Ensure system block carried cache_control by default.
        self.assertEqual(
            sent["system"][0]["cache_control"], {"type": "ephemeral"}
        )

    def test_returns_none_on_empty_response(self) -> None:
        client = _FakeClient(_FakeResponse(""))
        out = llm_client.call_messages(
            client, llm_client.LLMConfig(), system="", user="x"
        )
        self.assertIsNone(out)

    def test_returns_none_on_exception(self) -> None:
        client = _FakeClient(RuntimeError("boom"))
        out = llm_client.call_messages(
            client, llm_client.LLMConfig(), system="", user="x"
        )
        self.assertIsNone(out)

    def test_timeout_override_routes_through_with_options(self) -> None:
        client = _FakeClient(_FakeResponse("ok"))
        out = llm_client.call_messages(
            client,
            llm_client.LLMConfig(),
            system="",
            user="x",
            timeout_sec=2.5,
        )
        self.assertEqual(out, "ok")

    def test_no_user_input_returns_none(self) -> None:
        client = _FakeClient(_FakeResponse("ok"))
        self.assertIsNone(
            llm_client.call_messages(
                client, llm_client.LLMConfig(), system="", user=""
            )
        )


class ValidateApiKeyEnvTests(unittest.TestCase):
    def test_normal_name_accepted(self) -> None:
        self.assertEqual(
            llm_client._validate_api_key_env("ANTHROPIC_API_KEY"),
            "ANTHROPIC_API_KEY",
        )

    def test_lowercase_rejected(self) -> None:
        # Must match ``^[A-Z][A-Z0-9_]{2,63}$`` so "anthropic_api_key" fails.
        self.assertEqual(
            llm_client._validate_api_key_env("anthropic_api_key"),
            llm_client.DEFAULT_API_KEY_ENV,
        )

    def test_blocklisted_names_rejected(self) -> None:
        for name in ("PATH", "HOME", "USERPROFILE", "USER", "TEMP"):
            self.assertEqual(
                llm_client._validate_api_key_env(name),
                llm_client.DEFAULT_API_KEY_ENV,
                f"failed to reject {name}",
            )

    def test_overlong_rejected(self) -> None:
        long_name = "A" + "B" * 80
        self.assertEqual(
            llm_client._validate_api_key_env(long_name),
            llm_client.DEFAULT_API_KEY_ENV,
        )

    def test_empty_rejected(self) -> None:
        self.assertEqual(
            llm_client._validate_api_key_env(""),
            llm_client.DEFAULT_API_KEY_ENV,
        )

    def test_invalid_chars_rejected(self) -> None:
        self.assertEqual(
            llm_client._validate_api_key_env("My-Key$"),
            llm_client.DEFAULT_API_KEY_ENV,
        )

    def test_from_dict_routes_through_validator(self) -> None:
        cfg = llm_client.LLMConfig.from_dict({"api_key_env": "PATH"})
        self.assertEqual(cfg.api_key_env, llm_client.DEFAULT_API_KEY_ENV)


class ParseJsonResponseLengthCapTests(unittest.TestCase):
    def test_input_under_cap_parsed(self) -> None:
        payload = '{"k": "' + "x" * 100 + '"}'
        self.assertIsNotNone(llm_client.parse_json_response(payload))

    def test_input_over_cap_rejected(self) -> None:
        # 64KiB cap; pad ~70KB of garbage prose around a tiny JSON.
        payload = "x" * (64 * 1024) + '{"a": 1}'
        self.assertIsNone(llm_client.parse_json_response(payload))


class GetClientTests(unittest.TestCase):
    def test_no_sdk_returns_none(self) -> None:
        with mock.patch.object(llm_client, "_anthropic", None):
            self.assertIsNone(
                llm_client.get_client(llm_client.LLMConfig(), "key")
            )

    def test_no_api_key_returns_none(self) -> None:
        # Even if SDK exists, an empty key short-circuits.
        fake_sdk = types.SimpleNamespace(Anthropic=lambda **kw: object())
        with mock.patch.object(llm_client, "_anthropic", fake_sdk):
            self.assertIsNone(
                llm_client.get_client(llm_client.LLMConfig(), "")
            )

    def test_construction_failure_returns_none(self) -> None:
        def boom(**kwargs):
            raise RuntimeError("network")

        fake_sdk = types.SimpleNamespace(Anthropic=boom)
        with mock.patch.object(llm_client, "_anthropic", fake_sdk):
            self.assertIsNone(
                llm_client.get_client(llm_client.LLMConfig(), "key-xyz")
            )

    def test_construction_success(self) -> None:
        sentinel = object()
        fake_sdk = types.SimpleNamespace(
            Anthropic=lambda **kwargs: sentinel
        )
        with mock.patch.object(llm_client, "_anthropic", fake_sdk):
            self.assertIs(
                llm_client.get_client(llm_client.LLMConfig(), "key-xyz"),
                sentinel,
            )


if __name__ == "__main__":
    unittest.main()
