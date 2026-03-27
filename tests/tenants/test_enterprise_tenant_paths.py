from __future__ import annotations

import json
import subprocess
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
SHARED_CONFIG = REPO_ROOT / "scripts" / "shared" / "config.sh"
SYNC_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "sync-tenant-enterprise-mapping.sh"
ONBOARD_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "onboard-enterprise-tenant.sh"
SEED_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "seed-siteconfigs.sh"
SITE_RECONCILE_COMMON = REPO_ROOT / "scripts" / "tenants" / "lib" / "site-reconcile-common.sh"
MULTISITE_BOOTSTRAP_DJANGO = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap_django.py"
VERIFY_MULTISITE_CONFIG = REPO_ROOT / "scripts" / "qa" / "verify-multisite-config.sh"


def bash_eval(command: str) -> str:
    result = subprocess.run(
        ["bash", "-lc", f'source "{SHARED_CONFIG}" >/dev/null 2>&1; {command}'],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def test_shared_config_resolves_active_nonprod_defaults() -> None:
    assert bash_eval("mereka_lms_default_context_for_env dev") == "rke2-nonprod"
    assert bash_eval("mereka_lms_default_namespace_for_env dev") == "mereka-lms-dev"
    assert bash_eval("mereka_lms_default_context_for_env staging") == "rke2-nonprod"
    assert bash_eval("mereka_lms_default_namespace_for_env staging") == "stg-mereka-lms"
    assert (
        bash_eval("mereka_lms_lms_base_url_for_env staging")
        == "https://staging.academyv2.mereka.io"
    )


def test_shared_config_builds_registry_backed_canonical_domain_map() -> None:
    staging_map = json.loads(bash_eval("mereka_lms_canonical_domain_map_json staging"))
    assert staging_map["mereka"] == "staging.academyv2.mereka.io"
    assert staging_map["bijibiji"] == "staging.academy.biji-biji.com"
    assert (
        staging_map["skillourfuture"]
        == "staging.skillourfuture.academy.mereka.io"
    )


def test_sync_script_uses_shared_env_resolution() -> None:
    text = SYNC_SCRIPT.read_text(encoding="utf-8")
    assert "--env prod|dev|staging" in text
    assert 'NAMESPACE="$(mereka_lms_default_namespace_for_env "$ENVIRONMENT")"' in text
    assert (
        'K8S_CONTEXT_EFFECTIVE="$(mereka_lms_default_context_for_env "$ENVIRONMENT")"'
        in text
    )
    assert 'CANONICAL_DOMAIN_MAP="$(mereka_lms_canonical_domain_map_json "$ENVIRONMENT")"' in text
    assert 'canonical = json.loads(os.environ.get("CANONICAL_DOMAIN_MAP", "{}"))' in text


def test_onboard_script_forces_staging_canonical_relink() -> None:
    text = ONBOARD_SCRIPT.read_text(encoding="utf-8")
    assert 'source "${REPO_ROOT}/scripts/shared/config.sh"' in text
    assert "--env prod|dev|staging" in text
    assert 'NAMESPACE="$(mereka_lms_default_namespace_for_env "$ENVIRONMENT")"' in text
    assert 'mapping_cmd+=(--canonical-domains)' in text
    assert '--namespace "$NAMESPACE"' in text


def test_seed_siteconfigs_preserves_enterprise_uuid_mapping() -> None:
    text = SEED_SCRIPT.read_text(encoding="utf-8")
    assert 'existing_values.get("ENTERPRISE_CUSTOMER_UUID", "")' in text
    assert "EnterpriseCustomer.objects.filter(site=site).first()" in text
    assert 'site_values["ENTERPRISE_CUSTOMER_UUID"] = enterprise_customer_uuid' in text


def test_siteconfig_seed_paths_enable_learner_home_mfe() -> None:
    seed_text = SEED_SCRIPT.read_text(encoding="utf-8")
    reconcile_text = SITE_RECONCILE_COMMON.read_text(encoding="utf-8")
    bootstrap_text = MULTISITE_BOOTSTRAP_DJANGO.read_text(encoding="utf-8")
    assert '"ENABLE_LEARNER_HOME_MFE": True' in seed_text
    assert '"ENABLE_LEARNER_HOME_MFE": True' in reconcile_text
    assert 'rendered_values["ENABLE_LEARNER_HOME_MFE"] = True' in bootstrap_text


def test_multisite_verifier_checks_authenticated_dashboard_handoff() -> None:
    text = VERIFY_MULTISITE_CONFIG.read_text(encoding="utf-8")
    assert "SafeCookieData.create" in text
    assert '"https://${domain}/dashboard"' in text
    assert 'expected_location="${expected_mfe_base%/}/learner-dashboard/"' in text
