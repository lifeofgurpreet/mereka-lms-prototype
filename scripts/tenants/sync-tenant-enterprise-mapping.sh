#!/usr/bin/env bash
# @covers AC-MTA-012, AC-MTA-013, AC-MTA-014
# @spec: multi-tenancy-architecture_spec.md
# Sync EnterpriseCustomer <-> SiteConfiguration mapping for tenant resolution.
#
# What this does:
#   1) Ensures SiteConfiguration.site_values.ENTERPRISE_CUSTOMER_UUID is populated
#      for every EnterpriseCustomer.site.
#   2) Optionally reconciles canonical tenant slug->domain site links.
#
# Usage:
#   ./scripts/tenants/sync-tenant-enterprise-mapping.sh --env staging --canonical-domains --dry-run
#   ./scripts/tenants/sync-tenant-enterprise-mapping.sh --env prod --canonical-domains --apply
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${REPO_ROOT}/scripts/shared/config.sh" 2>/dev/null || true

ENVIRONMENT="prod"
NAMESPACE="${K8S_NAMESPACE:-}"
CONTEXT_OVERRIDE=""
CANONICAL_DOMAINS=0
DRY_RUN=1
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING="${CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING:-}"
CONFIRM_TOKEN="SYNC_TENANT_ENTERPRISE_MAPPING"

usage() {
  cat <<'USAGE'
Usage: sync-tenant-enterprise-mapping.sh [OPTIONS]

Options:
  --env prod|dev|staging  Target environment (default: prod)
  --namespace <ns>        Kubernetes namespace (default: env-specific lane)
  --context <ctx>         Override kubectl context
  --canonical-domains     Reconcile known tenant slugs to canonical domains first
  --apply                 Apply changes (default: dry-run)
  --dry-run               Preview only (default)
  -h, --help              Show this help

Safety controls for --apply:
  CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING=SYNC_TENANT_ENTERPRISE_MAPPING
  ALLOW_PROD_APPLY=1      Required for prod-like contexts
  CREATE_PREOP_BACKUP=1   Default for prod-like contexts (Velero pre-op backup)
USAGE
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *)
      echo "Invalid ${var_name}='${value}' (expected 0 or 1)" >&2
      exit 1
      ;;
  esac
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing command: $cmd" >&2
    exit 1
  }
}

is_prod_like_context() {
  local ctx="$1"
  [[ "$ctx" == *"gke_bbi-k8"* ]] || [[ "$ctx" == "prod" ]] || [[ "$ctx" == "production" ]] || [[ "$ctx" == "gke-prod" ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --context)
      CONTEXT_OVERRIDE="$2"
      shift 2
      ;;
    --canonical-domains)
      CANONICAL_DOMAINS=1
      shift
      ;;
    --apply)
      DRY_RUN=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! ENVIRONMENT="$(mereka_lms_normalize_env "$ENVIRONMENT")"; then
  echo "Invalid --env '$ENVIRONMENT' (expected prod|dev|staging)" >&2
  exit 1
fi

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"
require_cmd kubectl
if [[ "$CANONICAL_DOMAINS" -eq 1 ]]; then
  require_cmd python3
fi

if [[ -z "$NAMESPACE" ]]; then
  NAMESPACE="$(mereka_lms_default_namespace_for_env "$ENVIRONMENT")"
fi

K8S_CONTEXT_EFFECTIVE="${CONTEXT_OVERRIDE}"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  K8S_CONTEXT_EFFECTIVE="$(mereka_lms_default_context_for_env "$ENVIRONMENT")"
fi

CANONICAL_DOMAIN_MAP="{}"
if [[ "$CANONICAL_DOMAINS" -eq 1 ]]; then
  CANONICAL_DOMAIN_MAP="$(mereka_lms_canonical_domain_map_json "$ENVIRONMENT")"
fi

context_args=()
if [[ -n "$K8S_CONTEXT_EFFECTIVE" ]]; then
  context_args+=(--context "$K8S_CONTEXT_EFFECTIVE")
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT_EFFECTIVE" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT_EFFECTIVE' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT_EFFECTIVE"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-tenant-mapping-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT_EFFECTIVE' (operator override)"
    fi
  fi
fi

echo "=== Tenant Enterprise Mapping Sync ==="
echo "env=${ENVIRONMENT} namespace=${NAMESPACE} context=${K8S_CONTEXT_EFFECTIVE}"
echo "canonical_domains=${CANONICAL_DOMAINS} dry_run=${DRY_RUN}"
echo ""

if ! kubectl "${context_args[@]}" get deploy lms -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "LMS deployment not found in namespace '${NAMESPACE}' (context: ${K8S_CONTEXT_EFFECTIVE})" >&2
  exit 1
fi

kubectl "${context_args[@]}" exec -i -n "$NAMESPACE" deploy/lms -- \
  env ENVIRONMENT="$ENVIRONMENT" CANONICAL_DOMAINS="$CANONICAL_DOMAINS" CANONICAL_DOMAIN_MAP="$CANONICAL_DOMAIN_MAP" DRY_RUN="$DRY_RUN" python - <<'PY'
import os
import json
import django

django.setup()

from django.contrib.sites.models import Site
from openedx.core.djangoapps.site_configuration.models import SiteConfiguration
from enterprise.models import EnterpriseCustomer

ENVIRONMENT = os.environ.get("ENVIRONMENT", "prod")
DRY_RUN = os.environ.get("DRY_RUN", "1") == "1"
CANONICAL_DOMAINS = os.environ.get("CANONICAL_DOMAINS", "0") == "1"
canonical = json.loads(os.environ.get("CANONICAL_DOMAIN_MAP", "{}"))

changed_site_links = 0
changed_site_configs = 0
warnings = 0
pending_sites = {}

if CANONICAL_DOMAINS:
    print("Reconciling canonical tenant slug -> domain site links...")
    for slug, domain in canonical.items():
        ec_qs = EnterpriseCustomer.objects.filter(slug=slug)
        if hasattr(EnterpriseCustomer, "created"):
            ec = ec_qs.order_by("-created").first()
        elif hasattr(EnterpriseCustomer, "modified"):
            ec = ec_qs.order_by("-modified").first()
        else:
            ec = ec_qs.first()
        if ec is None:
            warnings += 1
            print(f"WARN: EnterpriseCustomer slug='{slug}' not found")
            continue
        site = Site.objects.filter(domain=domain).first()
        if site is None:
            warnings += 1
            print(f"WARN: Site domain='{domain}' not found for slug='{slug}'")
            continue
        if ec.site_id != site.id:
            print(f"RELINK: {slug} site_id {ec.site_id} -> {site.id} ({domain})")
            if not DRY_RUN:
                ec.site = site
                ec.save(update_fields=["site"])
            else:
                pending_sites[ec.pk] = site
            changed_site_links += 1
        else:
            print(f"OK: {slug} already linked to {domain}")

print("Syncing SiteConfiguration ENTERPRISE_CUSTOMER_UUID values...")
for ec in EnterpriseCustomer.objects.select_related("site").all().order_by("slug"):
    target_site = pending_sites.get(ec.pk) or ec.site
    if target_site is None:
        warnings += 1
        print(f"WARN: {ec.slug} has no site_id")
        continue

    cfg, created = SiteConfiguration.objects.get_or_create(
        site=target_site,
        defaults={"enabled": True, "site_values": {}},
    )
    values = cfg.site_values or {}
    current_uuid = str(values.get("ENTERPRISE_CUSTOMER_UUID", "")).strip()
    desired_uuid = str(ec.uuid)
    if current_uuid != desired_uuid:
        print(
            f"SYNC: domain={target_site.domain} slug={ec.slug} "
            f"ENTERPRISE_CUSTOMER_UUID {current_uuid or 'unset'} -> {desired_uuid}"
        )
        if not DRY_RUN:
            values["ENTERPRISE_CUSTOMER_UUID"] = desired_uuid
            cfg.site_values = values
            cfg.enabled = True
            cfg.save(update_fields=["site_values", "enabled"])
        changed_site_configs += 1
    else:
        print(f"OK: domain={target_site.domain} slug={ec.slug} uuid={desired_uuid}")

summary = {
    "dry_run": DRY_RUN,
    "canonical_domains": CANONICAL_DOMAINS,
    "changed_site_links": changed_site_links,
    "changed_site_configs": changed_site_configs,
    "warnings": warnings,
}
print("SUMMARY:")
print(json.dumps(summary, indent=2, sort_keys=True))
PY
