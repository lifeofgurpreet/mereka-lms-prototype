from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
LMS_SETTINGS = REPO_ROOT / "infrastructure/tutor/plugins/_mereka_lms/lms_settings.py"
INFRA_PLUGIN = REPO_ROOT / "infrastructure/tutor/plugins/_mereka_lms/infrastructure.py"
READINESS = REPO_ROOT / "scripts/infra/verify-local-bootstrap-readiness.sh"
SETUP_LOCAL = REPO_ROOT / "scripts/shared/setup-local.sh"
VERIFY_SETUP = REPO_ROOT / "scripts/qa/verify-setup.sh"
BOOTSTRAP_WORKFLOW = REPO_ROOT / ".github/workflows/bootstrap-local-readiness.yml"
TUTOR_CONFIG_SAVE = REPO_ROOT / "scripts/infra/tutor-config-save.sh"


def test_mfe_host_is_allowed_for_mfe_prefixed_lms_routes() -> None:
    settings = LMS_SETTINGS.read_text(encoding="utf-8")
    infra = INFRA_PLUGIN.read_text(encoding="utf-8")

    assert '["{{ MFE_HOST }}"] + {{ MEREKA_LMS_EXTRA_HOSTS }}' in settings
    assert '"http://{{ MFE_HOST }}"' in settings
    assert '"https://{{ MFE_HOST }}"' in settings
    assert "'{{ MFE_HOST }}'" in infra


def test_theme_convergence_is_skipped_when_image_lacks_repo_theme() -> None:
    infra = INFRA_PLUGIN.read_text(encoding="utf-8")

    assert "Path('/openedx/themes/mereka')" in infra
    assert "skipping SiteTheme convergence" in infra
    assert "Site.objects.get_or_create(domain=domain)" in infra


def test_local_readiness_fails_on_bad_mfe_authn_http_status() -> None:
    readiness = READINESS.read_text(encoding="utf-8")

    assert "MFE_AUTHN_URL" in readiness
    assert "apps.localhost/authn/login" in readiness
    assert "%{http_code}" in readiness
    assert 'check_http_route "$MFE_AUTHN_URL" "MFE authn" "200 302"' in readiness


def test_user_facing_setup_checks_http_status_not_just_connectivity() -> None:
    setup = SETUP_LOCAL.read_text(encoding="utf-8")
    verify_setup = VERIFY_SETUP.read_text(encoding="utf-8")

    for script in (setup, verify_setup):
        assert "apps.localhost/authn/login" in script
        assert "%{http_code}" in script
        assert " 200 302 " in script


def test_bootstrap_preclean_removes_stale_tutor_project_state() -> None:
    workflow = BOOTSTRAP_WORKFLOW.read_text(encoding="utf-8")

    assert "cleanup_tutor_project_state()" in workflow
    assert "docker ps -aq --filter name=tutor_local" in workflow
    assert "docker volume ls -q --filter name=tutor_local" in workflow
    assert "docker network ls -q --filter name=tutor_local" in workflow
    assert "mirror.gcr.io/library/alpine:3.20" in workflow
    assert "\n              alpine:3.20 \\\n" not in workflow


def test_tutor_config_save_tolerates_already_enabled_canonical_plugins() -> None:
    script = TUTOR_CONFIG_SAVE.read_text(encoding="utf-8")

    assert "plugin_enabled_in_config()" in script
    assert 'enable_output="$(tutor plugins enable "$plugin" 2>&1)"' in script
    assert "Canonical Tutor plugin already enabled in config" in script
    assert 'printf \'%s\\n\' "$enable_output" >&2' in script
