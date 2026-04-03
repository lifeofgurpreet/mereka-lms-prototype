from __future__ import annotations

import json
import subprocess
from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[2]
SHARED_CONFIG = REPO_ROOT / "scripts" / "shared" / "config.sh"
SYNC_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "sync-tenant-enterprise-mapping.sh"
SYNC_BRANDING_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "sync-tenant-branding.sh"
ONBOARD_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "onboard-enterprise-tenant.sh"
PROVISION_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "provision-tenant.sh"
SEED_SCRIPT = REPO_ROOT / "scripts" / "tenants" / "seed-siteconfigs.sh"
SITE_RECONCILE_COMMON = REPO_ROOT / "scripts" / "tenants" / "lib" / "site-reconcile-common.sh"
MULTISITE_BOOTSTRAP_DJANGO = REPO_ROOT / "scripts" / "shared" / "multisite_bootstrap_django.py"
VERIFY_MULTISITE_CONFIG = REPO_ROOT / "scripts" / "qa" / "verify-multisite-config.sh"
BIJI_BRANDING = REPO_ROOT / "scripts" / "tenants" / "biji-biji-branding.json"
SKILLOURFUTURE_BRANDING = REPO_ROOT / "scripts" / "tenants" / "skillourfuture-branding.json"
DEV_MULTISITE_DEFINITIONS = REPO_ROOT / "infrastructure" / "tutor" / "multisite-sites.dev.yml"
CADDYFILE = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "caddy" / "Caddyfile"
CADDY_DEPLOYMENT = REPO_ROOT / "deploy" / "k8s" / "base" / "apps" / "caddy" / "deployment.yaml"
GENERATED_DEV_CADDY_ENV = REPO_ROOT / "generated" / "domains" / "dev" / "caddy-env-patch.yaml"
LOCAL_DOMAIN_ENV = REPO_ROOT / "deploy" / "k8s" / "overlays" / "local" / "patches" / "domain-env.yaml"


def bash_eval(command: str) -> str:
    result = subprocess.run(
        ["bash", "-lc", f'source "{SHARED_CONFIG}" >/dev/null 2>&1; {command}'],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def yaml_caddy_env_map(path: Path) -> dict[str, str]:
    for document in yaml.safe_load_all(path.read_text(encoding="utf-8")):
        if not isinstance(document, dict):
            continue
        if document.get("kind") != "Deployment":
            continue
        if document.get("metadata", {}).get("name") != "caddy":
            continue
        env = document["spec"]["template"]["spec"]["containers"][0]["env"]
        return {item["name"]: item["value"] for item in env}
    raise AssertionError(f"Could not find caddy deployment in {path}")


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


def test_seed_paths_upsert_non_primary_mfe_hosts_like_bootstrap() -> None:
    seed_text = SEED_SCRIPT.read_text(encoding="utf-8")
    reconcile_text = SITE_RECONCILE_COMMON.read_text(encoding="utf-8")
    bootstrap_text = MULTISITE_BOOTSTRAP_DJANGO.read_text(encoding="utf-8")

    assert 'mfe_host = urlparse(mfe_url).netloc or ""' in seed_text
    assert 'defaults={"name": f"{name} Apps"}' in seed_text
    assert 'mfe_site_values["domain"] = mfe_host' in seed_text
    assert 'mfe_site_values["MFE_CONFIG"] = dict(site_values.get("MFE_CONFIG", {}))' in seed_text

    assert 'mfe_host = urlparse(mfe_url).netloc or ""' in reconcile_text
    assert 'defaults={"name": f"{name} Apps"}' in reconcile_text
    assert 'mfe_site_values["domain"] = mfe_host' in reconcile_text
    assert 'mfe_site_values["MFE_CONFIG"] = dict(site_values.get("MFE_CONFIG", {}))' in reconcile_text

    assert "Ensure MFE host itself resolves through SiteConfiguration overrides." in bootstrap_text


def test_multisite_verifier_checks_authenticated_dashboard_handoff() -> None:
    text = VERIFY_MULTISITE_CONFIG.read_text(encoding="utf-8")
    assert "SafeCookieData.create" in text
    assert '"https://${domain}/dashboard"' in text
    assert 'expected_location="${expected_mfe_base%/}/learner-dashboard/"' in text


def test_sync_branding_prefers_canonical_repo_payloads() -> None:
    text = SYNC_BRANDING_SCRIPT.read_text(encoding="utf-8")
    assert 'CANONICAL_BRANDING_FILE="$REPO_ROOT/scripts/tenants/${SLUG}-branding.json"' in text
    assert 'BRANDING_FILE="$CANONICAL_BRANDING_FILE"' in text


def test_provision_and_onboard_thread_canonical_branding_file() -> None:
    provision_text = PROVISION_SCRIPT.read_text(encoding="utf-8")
    onboard_text = ONBOARD_SCRIPT.read_text(encoding="utf-8")
    assert '--branding-file' in provision_text
    assert 'CANONICAL_BRANDING_FILE="$REPO_ROOT/scripts/tenants/${SLUG}-branding.json"' in provision_text
    assert 'CANONICAL_BRANDING_FILE="$REPO_ROOT/scripts/tenants/${SLUG}-branding.json"' in onboard_text
    assert 'provision_cmd+=(--branding-file "$CANONICAL_BRANDING_FILE")' in onboard_text
    assert 'branding_cmd+=(--branding-file "$CANONICAL_BRANDING_FILE")' in onboard_text


def test_canonical_branding_payloads_exist_for_active_dev_tenants() -> None:
    biji = json.loads(BIJI_BRANDING.read_text(encoding="utf-8"))
    skill = json.loads(SKILLOURFUTURE_BRANDING.read_text(encoding="utf-8"))

    assert biji["slug"] == "biji-biji"
    assert biji["name"] == "Biji-Biji Academy"
    assert biji["domain"] == "biji-biji.academyv2.mereka.dev"
    assert biji["colors"]["primary"] == "#000000"
    assert biji["colors"]["secondary"] == "#4b5563"
    assert biji["colors"]["accent"] == "#374151"
    assert biji["colors"]["text_on_primary"] == "#ffffff"
    assert biji["logos"]["logo_url"] == "/theme/logo-horizontal.png"
    assert biji["footer"]["contact_email"] == "admin@biji-biji.com"

    assert skill["slug"] == "skillourfuture"
    assert skill["name"] == "Skill Our Future"
    assert skill["domain"] == "skillourfuture.academyv2.mereka.dev"
    assert skill["colors"]["primary"] == "#450b7f"
    assert skill["colors"]["secondary"] == "#82c3c7"
    assert skill["colors"]["accent"] == "#0063ac"
    assert skill["colors"]["text_on_primary"] == "#ffffff"
    assert skill["logos"]["logo_url"] == "/theme/logo-horizontal.png"
    assert skill["footer"]["contact_email"] == "admin@mereka.io"


def test_dev_multisite_definitions_cover_active_non_primary_tenants() -> None:
    payload = yaml.safe_load(DEV_MULTISITE_DEFINITIONS.read_text(encoding="utf-8"))
    domains = {site["domain"] for site in payload["sites"]}

    assert "biji-biji.academyv2.mereka.dev" in domains
    assert "skillourfuture.academyv2.mereka.dev" in domains


def test_outer_caddy_binds_non_primary_tenant_apps_hosts_explicitly() -> None:
    caddy_text = CADDYFILE.read_text(encoding="utf-8")
    deployment = yaml.safe_load(CADDY_DEPLOYMENT.read_text(encoding="utf-8"))
    env = deployment["spec"]["template"]["spec"]["containers"][0]["env"]
    env_map = {item["name"]: item["value"] for item in env}

    assert "http://{$TENANT_BIJIBIJI_MFE_HOST:apps-bijibiji.invalid}" in caddy_text
    assert "http://{$TENANT_SOF_MFE_HOST:apps-sof.invalid}" in caddy_text
    assert "http://{$MFE_HOST} {" in caddy_text
    assert 'value: "apps.localhost"' not in caddy_text

    assert env_map["MFE_HOST"] == "apps.localhost"
    assert env_map["TENANT_BIJIBIJI_MFE_HOST"] == "apps-bijibiji.invalid"
    assert env_map["TENANT_SOF_MFE_HOST"] == "apps-sof.invalid"


def test_outer_caddy_binds_non_primary_tenant_lms_hosts_explicitly() -> None:
    caddy_text = CADDYFILE.read_text(encoding="utf-8")
    deployment = yaml.safe_load(CADDY_DEPLOYMENT.read_text(encoding="utf-8"))
    env = deployment["spec"]["template"]["spec"]["containers"][0]["env"]
    env_map = {item["name"]: item["value"] for item in env}

    assert "http://{$TENANT_BIJIBIJI_LMS_HOST:bijibiji.invalid}" in caddy_text
    assert "http://{$TENANT_SOF_LMS_HOST:sof.invalid}" in caddy_text
    assert env_map["TENANT_BIJIBIJI_LMS_HOST"] == "bijibiji.invalid"
    assert env_map["TENANT_SOF_LMS_HOST"] == "sof.invalid"


def test_dev_domain_projections_include_non_primary_lms_hosts_for_caddy() -> None:
    generated_dev_map = yaml_caddy_env_map(GENERATED_DEV_CADDY_ENV)
    local_overlay_map = yaml_caddy_env_map(LOCAL_DOMAIN_ENV)

    assert generated_dev_map["TENANT_BIJIBIJI_LMS_HOST"] == "biji-biji.academyv2.mereka.dev"
    assert generated_dev_map["TENANT_SOF_LMS_HOST"] == "skillourfuture.academyv2.mereka.dev"
    assert generated_dev_map["TENANT_BIJIBIJI_MFE_HOST"] == "apps.biji-biji.academyv2.mereka.dev"
    assert generated_dev_map["TENANT_SOF_MFE_HOST"] == "apps.skillourfuture.academyv2.mereka.dev"

    assert local_overlay_map["TENANT_BIJIBIJI_LMS_HOST"] == "biji-biji.academyv2.mereka.dev"
    assert local_overlay_map["TENANT_SOF_LMS_HOST"] == "skillourfuture.academyv2.mereka.dev"
