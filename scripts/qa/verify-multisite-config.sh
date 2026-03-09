#!/usr/bin/env bash
# @covers AC-001, AC-005
# @spec: multi-site-domains_spec.md
# Validate Site + SiteConfiguration entries for academyv2 microsites.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

ENVIRONMENT="${1:-prod}"
shift || true
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" ]]; then
  echo "Usage: $0 [prod|dev|staging] [--context CONTEXT] [--namespace NS]" >&2
  exit 1
fi

NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
STRICT="${STRICT:-0}"
CTX_OVERRIDE=""

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid $var_name='$value' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      CTX_OVERRIDE="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Default contexts per environment (avoid accidentally checking dev values in prod DB).
DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
DEFAULT_STAGING_CTX="rke2-nonprod"
K8S_CONTEXT_EFFECTIVE="${CTX_OVERRIDE:-}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
  elif [[ "$ENVIRONMENT" == "staging" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT_STAGING:-${K8S_CONTEXT:-$DEFAULT_STAGING_CTX}}"
    NAMESPACE="${K8S_NAMESPACE_STAGING:-stg-mereka-lms}"
  else
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-$DEFAULT_DEV_CTX}}"
  fi
fi

CONTEXT_ARGS=()
if [[ -n "${K8S_CONTEXT_EFFECTIVE:-}" ]]; then
  CONTEXT_ARGS+=(--context "${K8S_CONTEXT_EFFECTIVE}")
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  DOMAINS=(
    "${LMS_DOMAIN}"
    "${BIJI_DOMAIN}"
    "${SKILLOURFUTURE_DOMAIN}"
  )
elif [[ "$ENVIRONMENT" == "staging" ]]; then
  DOMAINS=(
    "${STAGING_LMS_DOMAIN}"
  )
else
  DOMAINS=(
    "${DEV_LMS_DOMAIN}"
  )
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  REQUIRE_ENTERPRISE_SITE_MAPPING="${REQUIRE_ENTERPRISE_SITE_MAPPING:-1}"
elif [[ "$ENVIRONMENT" == "staging" ]]; then
  REQUIRE_ENTERPRISE_SITE_MAPPING="${REQUIRE_ENTERPRISE_SITE_MAPPING:-0}"
else
  REQUIRE_ENTERPRISE_SITE_MAPPING="${REQUIRE_ENTERPRISE_SITE_MAPPING:-0}"
fi
require_bool_01 "STRICT" "$STRICT"
require_bool_01 "REQUIRE_ENTERPRISE_SITE_MAPPING" "$REQUIRE_ENTERPRISE_SITE_MAPPING"

export DOMAINS_CSV
DOMAINS_CSV=$(IFS=, ; echo "${DOMAINS[*]}")

EXPECTED_JSON=$(
  python3 - <<PY
import json, os

lms = os.environ.get("LMS_DOMAIN", "academyv2.mereka.io")
studio = os.environ.get("STUDIO_DOMAIN", f"studio.{lms}")
mfe = os.environ.get("MFE_DOMAIN", f"apps.{lms}")
biji = os.environ.get("BIJI_DOMAIN", "academy.biji-biji.com")
biji_studio = os.environ.get("BIJI_STUDIO_DOMAIN", "studio.academy.biji-biji.com")
biji_mfe = os.environ.get("BIJI_MFE_DOMAIN", "apps.academy.biji-biji.com")
skill = os.environ.get("SKILLOURFUTURE_DOMAIN", "skillourfuture.academy.mereka.io")
skill_studio = os.environ.get("SKILLOURFUTURE_STUDIO_DOMAIN", f"studio.{skill}")
skill_mfe = os.environ.get("SKILLOURFUTURE_MFE_DOMAIN", f"apps.{skill}")
dev = os.environ.get("DEV_LMS_DOMAIN", "academyv2.mereka.dev")
dev_studio = os.environ.get("DEV_STUDIO_DOMAIN", f"studio.{dev}")
dev_mfe = os.environ.get("DEV_MFE_DOMAIN", f"apps.{dev}")
staging = os.environ.get("STAGING_LMS_DOMAIN", "staging.academyv2.mereka.io")
staging_studio = os.environ.get("STAGING_STUDIO_DOMAIN", f"studio.{staging}")
staging_mfe = os.environ.get("STAGING_MFE_DOMAIN", f"apps.{staging}")

base = {"THEME_NAME": "mereka"}

expected = {
  lms: {
    **base,
    "LMS_ROOT_URL": f"https://{lms}",
    "CMS_ROOT_URL": f"https://{studio}",
    "MFE_BASE_URL": f"https://{mfe}",
    "COURSE_ORG_FILTER": ["MEREKA"],
  },
  biji: {
    **base,
    "LMS_ROOT_URL": f"https://{biji}",
    "CMS_ROOT_URL": f"https://{biji_studio}",
    "MFE_BASE_URL": f"https://{biji_mfe}",
    "COURSE_ORG_FILTER": ["BIJIBIJI"],
  },
  skill: {
    **base,
    "LMS_ROOT_URL": f"https://{skill}",
    "CMS_ROOT_URL": f"https://{skill_studio}",
    "MFE_BASE_URL": f"https://{skill_mfe}",
    "COURSE_ORG_FILTER": ["SKILLOURFUTURE"],
  },
  dev: {
    **base,
    "LMS_ROOT_URL": f"https://{dev}",
    "CMS_ROOT_URL": f"https://{dev_studio}",
    "MFE_BASE_URL": f"https://{dev_mfe}",
    "COURSE_ORG_FILTER": ["MEREKA"],
  },
  staging: {
    **base,
    "LMS_ROOT_URL": f"https://{staging}",
    "CMS_ROOT_URL": f"https://{staging_studio}",
    "MFE_BASE_URL": f"https://{staging_mfe}",
    "COURSE_ORG_FILTER": ["BBI", "Mereka"],
  },
}

print(json.dumps(expected, sort_keys=True))
PY
)

# Early-exit when no cluster is available (CI without kubectl context).
# Use a short timeout so a stale/unreachable context doesn't cause a multi-minute hang.
_CLUSTER_CHECK_TIMEOUT="${CLUSTER_CHECK_TIMEOUT:-20}"
if ! command -v kubectl >/dev/null 2>&1; then
  echo "⚠ SKIP: kubectl not found — skipping multisite config runtime checks"
  echo "  (Run with a valid KUBECONFIG/cluster context to execute AC-001, AC-005)"
  exit 0
fi

_cluster_reachable=0
if command -v timeout >/dev/null 2>&1; then
  if timeout "${_CLUSTER_CHECK_TIMEOUT}s" kubectl "${CONTEXT_ARGS[@]}" cluster-info >/dev/null 2>&1; then
    _cluster_reachable=1
  fi
else
  # No timeout binary; try once with a short connect timeout via kubectl --request-timeout.
  if kubectl "${CONTEXT_ARGS[@]}" --request-timeout="${_CLUSTER_CHECK_TIMEOUT}s" cluster-info >/dev/null 2>&1; then
    _cluster_reachable=1
  fi
fi

if [[ "$_cluster_reachable" -eq 0 ]]; then
  echo "⚠ SKIP: kubectl cluster unreachable (context=${K8S_CONTEXT_EFFECTIVE:-default}, timeout=${_CLUSTER_CHECK_TIMEOUT}s) — skipping multisite config runtime checks"
  echo "  (Run with a reachable cluster context to execute AC-001, AC-005)"
  exit 0
fi

kubectl "${CONTEXT_ARGS[@]}" exec -i -n "${NAMESPACE}" deploy/lms -- env DOMAINS="${DOMAINS_CSV}" STRICT="${STRICT}" EXPECTED_JSON="${EXPECTED_JSON}" REQUIRE_ENTERPRISE_SITE_MAPPING="${REQUIRE_ENTERPRISE_SITE_MAPPING}" python - <<'PY'
import os
import sys
import json
import django
from django.db.utils import OperationalError

django.setup()

from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration

domains = [d.strip() for d in os.environ.get("DOMAINS", "").split(",") if d.strip()]
strict = os.environ.get("STRICT", "0") == "1"
expected = json.loads(os.environ.get("EXPECTED_JSON", "{}") or "{}")
require_site_mapping = os.environ.get("REQUIRE_ENTERPRISE_SITE_MAPPING", "0") == "1"

try:
    from enterprise.models import EnterpriseCustomer
except Exception:
    EnterpriseCustomer = None

missing = []
bad = []
hints = []
for domain in domains:
    site = Site.objects.filter(domain=domain).first()
    if not site:
        print(f"{domain}: SITE_MISSING")
        missing.append(domain)
        continue
    cfg_qs = SiteConfiguration.objects.filter(site=site).order_by("-id")
    cfg = cfg_qs.first()
    if not cfg:
        print(f"{domain}: CONFIG_MISSING")
        missing.append(domain)
        continue
    if cfg_qs.count() > 1:
        bad.append(f"{domain}: duplicate SiteConfiguration rows={cfg_qs.count()} (expected 1)")
    values = cfg.site_values or {}
    enabled = bool(getattr(cfg, "enabled", False))
    theme = values.get("THEME_NAME", "unset")
    lms_root = values.get("LMS_ROOT_URL") or "unset"
    cms_root = values.get("CMS_ROOT_URL") or "unset"
    mfe_base = values.get("MFE_BASE_URL") or "unset"
    org_filter = values.get("course_org_filter") or []
    if isinstance(org_filter, str):
        org_filter = [org_filter]
    if not isinstance(org_filter, list):
        org_filter = [str(org_filter)]
    org_filter_norm = sorted(str(x).strip() for x in org_filter if str(x).strip())
    print(
        f"{domain}: enabled={enabled} theme={theme} "
        f"lms_root={lms_root} cms_root={cms_root} mfe_base={mfe_base} "
        f"org_filter={','.join(org_filter_norm) if org_filter_norm else 'unset'}"
    )

    exp = expected.get(domain) or {}
    exp_lms = exp.get("LMS_ROOT_URL")
    exp_cms = exp.get("CMS_ROOT_URL")
    exp_mfe = exp.get("MFE_BASE_URL")
    exp_theme = exp.get("THEME_NAME")
    exp_orgs = sorted((exp.get("COURSE_ORG_FILTER") or []))
    site_domain = values.get("domain")
    if not enabled:
        bad.append(f"{domain}: SiteConfiguration enabled=false")
    if site_domain and site_domain != domain:
        bad.append(f"{domain}: site_values.domain expected={domain} got={site_domain}")
    if exp_lms and lms_root != exp_lms:
        bad.append(f"{domain}: LMS_ROOT_URL expected={exp_lms} got={lms_root}")
    if exp_cms and cms_root != exp_cms:
        bad.append(f"{domain}: CMS_ROOT_URL expected={exp_cms} got={cms_root}")
        if (
            domain != os.environ.get("LMS_DOMAIN", "academyv2.mereka.io")
            and exp_cms.startswith("https://studio.")
            and cms_root.startswith("https://studio.academyv2.")
        ):
            hints.append(
                f"{domain}: runtime still uses shared Studio root; expected tenant-owned host. "
                "Remediation: rerun multisite bootstrap/apply flow and verify latest config rollout."
            )
    if exp_mfe and mfe_base != exp_mfe:
        bad.append(f"{domain}: MFE_BASE_URL expected={exp_mfe} got={mfe_base}")
        if (
            domain != os.environ.get("LMS_DOMAIN", "academyv2.mereka.io")
            and exp_mfe.startswith("https://apps.")
            and mfe_base.startswith("https://apps.academyv2.")
        ):
            hints.append(
                f"{domain}: runtime still uses shared MFE root; expected tenant-owned host. "
                "Remediation: rerun multisite bootstrap/apply flow and verify latest config rollout."
            )
    if exp_theme and theme != exp_theme:
        bad.append(f"{domain}: THEME_NAME expected={exp_theme} got={theme}")
    if exp_orgs and org_filter_norm != exp_orgs:
        bad.append(
            f"{domain}: course_org_filter expected={','.join(exp_orgs)} "
            f"got={','.join(org_filter_norm) if org_filter_norm else 'unset'}"
        )

    if EnterpriseCustomer is None:
        if require_site_mapping:
            bad.append(f"{domain}: enterprise app unavailable, cannot validate tenant-site mapping")
        continue

    # EnterpriseCustomer may use a non-integer PK (uuid) in some builds,
    # so avoid ordering by a hardcoded "id" field.
    try:
        ec_qs = EnterpriseCustomer.objects.filter(site=site)
        if hasattr(EnterpriseCustomer, "created"):
            ec = ec_qs.order_by("-created").first()
        elif hasattr(EnterpriseCustomer, "modified"):
            ec = ec_qs.order_by("-modified").first()
        else:
            ec = ec_qs.first()
    except OperationalError as exc:
        if require_site_mapping:
            bad.append(f"{domain}: enterprise mapping query failed: {exc}")
        else:
            print(f"{domain}: enterprise mapping query skipped (non-strict schema): {exc}")
        continue
    cfg_uuid = str(values.get("ENTERPRISE_CUSTOMER_UUID", "")).strip()
    if ec is None:
        if require_site_mapping:
            bad.append(f"{domain}: no EnterpriseCustomer linked to this Site (site_id={site.id})")
        continue
    expected_uuid = str(ec.uuid)
    if cfg_uuid != expected_uuid:
        bad.append(
            f"{domain}: ENTERPRISE_CUSTOMER_UUID expected={expected_uuid} got={cfg_uuid or 'unset'}"
        )
    else:
        print(f"{domain}: enterprise_uuid={expected_uuid} mapping=ok")

if bad:
    for line in bad:
        print(f"{line} :: MISMATCH")
if hints:
    for line in hints:
        print(f"{line} :: HINT")

if missing and strict:
    sys.exit(1)
if bad and strict:
    sys.exit(1)
PY
