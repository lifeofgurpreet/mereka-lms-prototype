#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-012, AC-043
# @spec: multi-tenancy-architecture_spec.md
# Deterministic workflow for onboarding a new enterprise tenant.
#
# Steps:
#   1) Provision/reconcile tenant Site + EnterpriseCustomer
#   2) Sync ENTERPRISE_CUSTOMER_UUID mapping into SiteConfiguration
#   3) Configure tenant IdP (SAML/OIDC)
#   4) Sync tenant branding assets scaffold
#   5) Run migration verification pipeline
#   6) Run runtime readiness checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SLUG=""
NAME=""
DOMAIN=""
CONTACT_EMAIL=""
COUNTRY=""
ENVIRONMENT="prod"
CONTEXT_OVERRIDE=""

IDP_TYPE=""
IDP_SLUG=""
DISPLAY_NAME=""
SAML_METADATA_URL=""
SAML_ENTITY_ID=""
OIDC_CLIENT_ID=""
OIDC_CLIENT_SECRET=""
OIDC_DISCOVERY_URL=""
OIDC_AUTH_URL=""
OIDC_TOKEN_URL=""
OIDC_USERINFO_URL=""

RUN_MIGRATION_VERIFICATION=1
RUN_RUNTIME_GATES=1
RUN_INTEGRITY_GUARD=1
RUN_SCHEMA_GUARD=1
DRY_RUN=1

usage() {
  cat <<'USAGE'
Usage: onboard-enterprise-tenant.sh [options]

Required:
  --slug <slug>
  --name <name>
  --domain <domain>
  --idp-type saml|oidc

Optional tenant fields:
  --contact-email <email>
  --country <iso2>
  --env prod|dev
  --context <kube-context>

Optional IdP fields:
  --idp-slug <slug>
  --display-name <name>
  --metadata-url <url>                (required for saml)
  --entity-id <entity-id>
  --client-id <id>                    (required for oidc)
  --client-secret <secret>            (required for oidc)
  --discovery-url <url>
  --auth-url <url>
  --token-url <url>
  --user-info-url <url>

Flow controls:
  --skip-migration-verification
  --skip-runtime-gates
  --skip-integrity-guard
  --skip-schema-guard
  --apply                             Apply changes (default dry-run)
  --dry-run                           Preview only (default)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slug) SLUG="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --contact-email) CONTACT_EMAIL="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;

    --idp-type) IDP_TYPE="$2"; shift 2 ;;
    --idp-slug) IDP_SLUG="$2"; shift 2 ;;
    --display-name) DISPLAY_NAME="$2"; shift 2 ;;
    --metadata-url) SAML_METADATA_URL="$2"; shift 2 ;;
    --entity-id) SAML_ENTITY_ID="$2"; shift 2 ;;
    --client-id) OIDC_CLIENT_ID="$2"; shift 2 ;;
    --client-secret) OIDC_CLIENT_SECRET="$2"; shift 2 ;;
    --discovery-url) OIDC_DISCOVERY_URL="$2"; shift 2 ;;
    --auth-url) OIDC_AUTH_URL="$2"; shift 2 ;;
    --token-url) OIDC_TOKEN_URL="$2"; shift 2 ;;
    --user-info-url) OIDC_USERINFO_URL="$2"; shift 2 ;;

    --skip-migration-verification) RUN_MIGRATION_VERIFICATION=0; shift ;;
    --skip-runtime-gates) RUN_RUNTIME_GATES=0; shift ;;
    --skip-integrity-guard) RUN_INTEGRITY_GUARD=0; shift ;;
    --skip-schema-guard) RUN_SCHEMA_GUARD=0; shift ;;
    --apply) DRY_RUN=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$SLUG" || -z "$NAME" || -z "$DOMAIN" || -z "$IDP_TYPE" ]]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

if [[ "$IDP_TYPE" != "saml" && "$IDP_TYPE" != "oidc" ]]; then
  echo "--idp-type must be saml|oidc" >&2
  exit 1
fi

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "--env must be prod|dev" >&2
  exit 1
fi

DEFAULT_PROD_CTX="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DEFAULT_DEV_CTX="kind-dev"
K8S_CONTEXT_EFFECTIVE="$CONTEXT_OVERRIDE"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_PROD_CTX}"
  else
    K8S_CONTEXT_EFFECTIVE="${K8S_CONTEXT:-$DEFAULT_DEV_CTX}"
  fi
fi

echo "=== Enterprise Tenant Onboarding Workflow ==="
echo "slug=$SLUG name=$NAME domain=$DOMAIN env=$ENVIRONMENT context=$K8S_CONTEXT_EFFECTIVE idp_type=$IDP_TYPE dry_run=$DRY_RUN"
echo ""

if [[ "$RUN_INTEGRITY_GUARD" -eq 1 ]]; then
  echo "[0/6] Run enterprise readiness integrity preflight"
  "$REPO_ROOT/scripts/qa/verify-enterprise-readiness-integrity.sh"
  echo ""
fi

provision_cmd=(
  "$REPO_ROOT/scripts/tenants/provision-tenant.sh"
  --context "$K8S_CONTEXT_EFFECTIVE"
  --slug "$SLUG"
  --name "$NAME"
  --domain "$DOMAIN"
)
[[ -n "$CONTACT_EMAIL" ]] && provision_cmd+=(--contact-email "$CONTACT_EMAIL")
[[ -n "$COUNTRY" ]] && provision_cmd+=(--country "$COUNTRY")
[[ "$DRY_RUN" -eq 1 ]] && provision_cmd+=(--dry-run)

mapping_cmd=(
  "$REPO_ROOT/scripts/tenants/sync-tenant-enterprise-mapping.sh"
  --env "$ENVIRONMENT"
  --context "$K8S_CONTEXT_EFFECTIVE"
)
[[ "$DRY_RUN" -eq 1 ]] && mapping_cmd+=(--dry-run) || mapping_cmd+=(--apply)

idp_cmd=(
  "$REPO_ROOT/scripts/tenants/configure-tenant-idp.sh"
  --env "$ENVIRONMENT"
  --context "$K8S_CONTEXT_EFFECTIVE"
  --tenant-slug "$SLUG"
  --idp-type "$IDP_TYPE"
)
[[ -n "$IDP_SLUG" ]] && idp_cmd+=(--idp-slug "$IDP_SLUG")
[[ -n "$DISPLAY_NAME" ]] && idp_cmd+=(--display-name "$DISPLAY_NAME")
if [[ "$IDP_TYPE" == "saml" ]]; then
  [[ -n "$SAML_METADATA_URL" ]] && idp_cmd+=(--metadata-url "$SAML_METADATA_URL")
  [[ -n "$SAML_ENTITY_ID" ]] && idp_cmd+=(--entity-id "$SAML_ENTITY_ID")
else
  [[ -n "$OIDC_CLIENT_ID" ]] && idp_cmd+=(--client-id "$OIDC_CLIENT_ID")
  [[ -n "$OIDC_CLIENT_SECRET" ]] && idp_cmd+=(--client-secret "$OIDC_CLIENT_SECRET")
  [[ -n "$OIDC_DISCOVERY_URL" ]] && idp_cmd+=(--discovery-url "$OIDC_DISCOVERY_URL")
  [[ -n "$OIDC_AUTH_URL" ]] && idp_cmd+=(--auth-url "$OIDC_AUTH_URL")
  [[ -n "$OIDC_TOKEN_URL" ]] && idp_cmd+=(--token-url "$OIDC_TOKEN_URL")
  [[ -n "$OIDC_USERINFO_URL" ]] && idp_cmd+=(--user-info-url "$OIDC_USERINFO_URL")
fi
[[ "$DRY_RUN" -eq 1 ]] && idp_cmd+=(--dry-run) || idp_cmd+=(--apply)

branding_cmd=("$REPO_ROOT/scripts/tenants/sync-tenant-branding.sh" --slug "$SLUG")
[[ "$DRY_RUN" -eq 1 ]] && branding_cmd+=(--dry-run)

echo "[1/6] Provision/reconcile tenant"
"${provision_cmd[@]}"
echo ""

echo "[2/6] Sync SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping"
"${mapping_cmd[@]}"
echo ""

echo "[3/6] Configure tenant IdP"
"${idp_cmd[@]}"
echo ""

echo "[4/6] Sync tenant branding scaffold"
"${branding_cmd[@]}"
echo ""

if [[ "$RUN_MIGRATION_VERIFICATION" -eq 1 ]]; then
  echo "[5/6] Run migration verification pipeline"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY-RUN: would run scripts/migrations/run-verification-pipeline.sh"
  else
    "$REPO_ROOT/scripts/migrations/run-verification-pipeline.sh"
  fi
  echo ""
else
  echo "[5/6] Skipped migration verification pipeline"
  echo ""
fi

if [[ "$RUN_RUNTIME_GATES" -eq 1 ]]; then
  echo "[6/6] Run runtime readiness gates"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ "$RUN_SCHEMA_GUARD" -eq 1 ]]; then
      echo "DRY-RUN: would run scripts/tenants/repair-enterprise-schema.sh --env $ENVIRONMENT"
    fi
    echo "DRY-RUN: would run scripts/qa/verify-enterprise-runtime-app-wiring.sh --env $ENVIRONMENT --context $K8S_CONTEXT_EFFECTIVE --strict"
    echo "DRY-RUN: would run scripts/qa/verify-enterprise-sso-readiness.sh --env $ENVIRONMENT --tenant $SLUG"
    echo "DRY-RUN: would run scripts/qa/verify-multisite-config.sh $ENVIRONMENT"
  else
    if [[ "$RUN_SCHEMA_GUARD" -eq 1 ]]; then
      "$REPO_ROOT/scripts/tenants/repair-enterprise-schema.sh" --env "$ENVIRONMENT"
    fi
    "$REPO_ROOT/scripts/qa/verify-enterprise-runtime-app-wiring.sh" \
      --env "$ENVIRONMENT" \
      --context "$K8S_CONTEXT_EFFECTIVE" \
      --strict
    "$REPO_ROOT/scripts/qa/verify-enterprise-sso-readiness.sh" --env "$ENVIRONMENT" --tenant "$SLUG"
    if [[ "$ENVIRONMENT" == "prod" ]]; then
      STRICT=1 REQUIRE_ENTERPRISE_SITE_MAPPING=1 \
        "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" "$ENVIRONMENT" --context "$K8S_CONTEXT_EFFECTIVE"
    else
      STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" "$ENVIRONMENT" --context "$K8S_CONTEXT_EFFECTIVE"
    fi
  fi
  echo ""
else
  echo "[6/6] Skipped runtime readiness gates"
  echo ""
fi

echo "Workflow complete."
