"""
Regression tests for the enterprise runtime truth tranche.

These tests pin the environment-selection contract for the enterprise SSO and
operations-gate proof scripts without touching live clusters.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
READINESS_SCRIPT = REPO_ROOT / "scripts" / "qa" / "verify-enterprise-sso-readiness.sh"
AUTH_SSO_SCRIPT = REPO_ROOT / "scripts" / "qa" / "verify-auth-sso-enterprise.sh"
OPERATIONS_GATES_SCRIPT = REPO_ROOT / "scripts" / "qa" / "run-operations-gates.sh"
OPERATIONS_GATES_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "operations-gates-runtime.yml"


def _run_bash(script: Path, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    run_env = os.environ.copy()
    if env:
        run_env.update(env)
    return subprocess.run(
        ["bash", str(script), *args],
        cwd=REPO_ROOT,
        env=run_env,
        capture_output=True,
        text=True,
        check=False,
    )


def _write_overlay(overlay_path: Path, domain: str) -> None:
    overlay_path.parent.mkdir(parents=True, exist_ok=True)
    overlay_path.write_text(
        "\n".join(
            [
                "MerekaOpenIdConnectAuthPKCE = True",
                f"SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = 'https://{domain}/application/o/mereka-lms/.well-known/openid-configuration'",
                'name = "oidc"',
                "DEFAULT_USE_PKCE = True",
                'PKCE_DEFAULT_CODE_CHALLENGE_METHOD = "S256"',
                "BaseOAuth2PKCE",
                "SESSION_COOKIE_SECURE = True",
                'SESSION_COOKIE_SAMESITE = "None"',
                "redis = True",
                "MerekaPlatformAdminMiddleware",
                "class MerekaPlatformAdminMiddleware: pass",
                "MEREKA_PLATFORM_ADMIN_EMAILS = []",
                "is_staff = True",
                "is_superuser = True",
                "email in _platform_admin_emails()",
                "ratelimit = True",
                "LOGIN_REDIRECT_WHITELIST = []",
                "SOCIAL_AUTH_SANITIZE_REDIRECTS = True",
                "SOCIAL_AUTH_ALLOWED_REDIRECT_HOSTS = []",
                "CSRF_COOKIE_SECURE = True",
                "SOCIAL_AUTH_REDIRECT_IS_HTTPS = True",
                "AUTHENTICATION_BACKENDS = []",
                "class StudioSSOBypassMiddleware: pass",
                "/oauth2/authorize",
                '"lms.envs.tutor.production.MerekaPlatformAdminMiddleware"',
                '"lms.envs.tutor.production.MerekaCookieDomainMiddleware"',
                "MIDDLEWARE.insert(0, _forwarded_headers_middleware)",
                "MIDDLEWARE.insert(1, _sso_bypass_middleware)",
                "cookie_index > session_index",
                "",
            ]
        ),
        encoding="utf-8",
    )


class TestEnterpriseSsoReadiness:
    def test_repo_mode_accepts_staging_env(self) -> None:
        result = _run_bash(READINESS_SCRIPT, "--mode", "repo", "--env", "staging")
        assert result.returncode == 0, (
            f"verify-enterprise-sso-readiness.sh failed.\n"
            f"stdout:\n{result.stdout}\n"
            f"stderr:\n{result.stderr}"
        )
        assert "env=staging  mode=repo" in result.stdout
        assert "Invalid --env" not in result.stderr


class TestEnterpriseAuthOverlaySelection:
    @pytest.mark.parametrize(
        ("env_name", "domain", "overlay_suffix"),
        [
            ("dev", "auth0.mereka.dev", "apps/mereka-lms/overlays/dev/patches/production-dev.py"),
            (
                "staging",
                "staging.auth0.mereka.io",
                "apps/mereka-lms/overlays/staging/patches/production-staging.py",
            ),
        ],
    )
    def test_env_selected_overlay_and_authentik_domain(
        self,
        tmp_path: Path,
        env_name: str,
        domain: str,
        overlay_suffix: str,
    ) -> None:
        fake_home = tmp_path / "home"
        fake_workspace = tmp_path / "workspace"
        fake_infra_root = fake_home / "projects" / "k8s" / "bbi-infrastructure"
        overlay_path = fake_infra_root / overlay_suffix

        for env, env_domain in {
            "prod": "auth0.mereka.io",
            "dev": "auth0.mereka.dev",
            "staging": "staging.auth0.mereka.io",
        }.items():
            suffix = f"apps/mereka-lms/overlays/{env}/patches/production-{env}.py"
            _write_overlay(fake_infra_root / suffix, env_domain)

        result = _run_bash(
            AUTH_SSO_SCRIPT,
            "--skip-cluster",
            "--env",
            env_name,
            env={
                "HOME": str(fake_home),
                "WORKSPACE_ROOT": str(fake_workspace),
            },
        )

        assert f"Overlay:   {overlay_path}" in result.stdout
        assert f"PASS: AC-004: Authentik OIDC provider configured in {env_name} overlay" in result.stdout
        assert domain in result.stdout
        assert f"production-{env_name}.py" in result.stdout


class TestOperationsGatesTruth:
    def test_operations_gates_defaults_and_staging_runtime_lane(self) -> None:
        script_text = OPERATIONS_GATES_SCRIPT.read_text(encoding="utf-8")
        workflow_text = OPERATIONS_GATES_WORKFLOW.read_text(encoding="utf-8")

        assert 'ENV_SCOPE="${ENV_SCOPE:-staging}"' in script_text
        assert 'K8S_NAMESPACE_STAGING="${K8S_NAMESPACE_STAGING:-stg-mereka-lms}"' in script_text
        assert 'staging) enterprise_envs=(staging) ;;' in script_text
        assert 'run_check "enterprise SSO readiness (${enterprise_env})"' in script_text

        assert 'default: "staging"' in workflow_text
        assert "vars.OPERATIONS_GATES_RUNTIME_ENV_SCOPE || 'staging'" in workflow_text
        assert "./scripts/qa/run-operations-gates.sh --env \"$INPUT_ENV_SCOPE\"" in workflow_text
        assert "RUN_ENTERPRISE_RUNTIME_AUDIT" in workflow_text
