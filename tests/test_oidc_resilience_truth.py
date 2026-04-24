"""Contract tests for the Authentik OIDC resilience block in production.py.

Issue: Biji-Biji-Initiative/mereka-lms#2090

We added a defensive block that:
  1. Wraps social_core.backends.oauth.BaseOAuth2.request with a default
     timeout (env var MEREKA_OIDC_REQUEST_TIMEOUT_SECONDS, default 10).
  2. Promotes social / social_core / social_django loggers so AuthCanceled
     tracebacks carry context into stdout.

Both behaviors are env-var gated. These tests lock in the *presence* of the
block so it cannot be silently stripped during a future refactor.
"""
from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LMS_SETTINGS = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "openedx" / "settings" / "lms" / "production.py"


def _read_lms_settings() -> str:
    return LMS_SETTINGS.read_text(encoding="utf-8")


def test_oidc_request_timeout_env_var_is_honored() -> None:
    text = _read_lms_settings()
    assert "MEREKA_OIDC_REQUEST_TIMEOUT_SECONDS" in text, (
        "Lost the env var hook used to tune Authentik OIDC client timeouts; "
        "see issue #2090."
    )


def test_oauth2_request_monkeypatch_is_present() -> None:
    text = _read_lms_settings()
    assert "BaseOAuth2.request" in text, (
        "social_core BaseOAuth2.request wrapper is missing; workers will "
        "stall on Authentik capacity flaps. See issue #2090."
    )
    assert "_mereka_timeout_patched" in text, (
        "Idempotency sentinel for the OIDC request monkeypatch is missing; "
        "repeated setting reloads could re-wrap the wrapper."
    )


def test_social_loggers_are_promoted() -> None:
    text = _read_lms_settings()
    for logger_name in ("social", "social_core", "social_django"):
        assert f'"{logger_name}"' in text, (
            f"social logger {logger_name!r} is no longer promoted; "
            "AuthCanceled tracebacks will be silent. See issue #2090."
        )


def test_oidc_debug_toggle_is_opt_in() -> None:
    text = _read_lms_settings()
    assert 'MEREKA_OIDC_DEBUG", "false"' in text, (
        "MEREKA_OIDC_DEBUG must default to 'false' — DEBUG-by-default would "
        "log access tokens in URL query strings. See issue #2090."
    )


def test_issue_reference_is_preserved() -> None:
    text = _read_lms_settings()
    assert "mereka-lms#2090" in text, (
        "The OIDC resilience block must cross-reference GitHub issue #2090 "
        "so operators can trace the rationale."
    )
