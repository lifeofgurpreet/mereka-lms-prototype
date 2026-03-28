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
# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

SLUG=""
NAME=""
DOMAIN=""
CONTACT_EMAIL=""
COUNTRY=""
ENVIRONMENT="prod"
CONTEXT_OVERRIDE=""
NAMESPACE="${K8S_NAMESPACE:-}"

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
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
CREATE_PREOP_BACKUP="${CREATE_PREOP_BACKUP:-1}"
CONFIRM_ONBOARD_ENTERPRISE_TENANT="${CONFIRM_ONBOARD_ENTERPRISE_TENANT:-}"
CONFIRM_TOKEN="ONBOARD_ENTERPRISE_TENANT"

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
  --env prod|dev|staging
  --context <kube-context>
  --namespace <ns>                   Default is environment-specific lane

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

Safety controls for --apply:
  CONFIRM_ONBOARD_ENTERPRISE_TENANT=ONBOARD_ENTERPRISE_TENANT
  ALLOW_PROD_APPLY=1                  Required for prod-like contexts
  CREATE_PREOP_BACKUP=1               Default for prod-like contexts (Velero pre-op backup)
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
    --slug) SLUG="$2"; shift 2 ;;
    --name) NAME="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --contact-email) CONTACT_EMAIL="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    --context) CONTEXT_OVERRIDE="$2"; shift 2 ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;

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

if ! ENVIRONMENT="$(mereka_lms_normalize_env "$ENVIRONMENT")"; then
  echo "--env must be prod|dev|staging" >&2
  exit 1
fi
require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "CREATE_PREOP_BACKUP" "$CREATE_PREOP_BACKUP"

if [[ -z "$NAMESPACE" ]]; then
  NAMESPACE="$(mereka_lms_default_namespace_for_env "$ENVIRONMENT")"
fi

K8S_CONTEXT_EFFECTIVE="$CONTEXT_OVERRIDE"
if [[ -z "$K8S_CONTEXT_EFFECTIVE" ]]; then
  K8S_CONTEXT_EFFECTIVE="$(mereka_lms_default_context_for_env "$ENVIRONMENT")"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "$CONFIRM_ONBOARD_ENTERPRISE_TENANT" != "$CONFIRM_TOKEN" ]]; then
    echo "Refusing --apply without explicit confirmation token. Set CONFIRM_ONBOARD_ENTERPRISE_TENANT=${CONFIRM_TOKEN}" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT_EFFECTIVE" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
    echo "Refusing --apply on prod-like context '$K8S_CONTEXT_EFFECTIVE' without ALLOW_PROD_APPLY=1" >&2
    exit 1
  fi

  if is_prod_like_context "$K8S_CONTEXT_EFFECTIVE"; then
    if [[ "$CREATE_PREOP_BACKUP" == "1" ]]; then
      require_cmd velero
      backup_name="pre-op-${NAMESPACE}-enterprise-onboard-$(date -u +%Y%m%d-%H%M)"
      echo "Creating Velero pre-op backup: $backup_name"
      velero backup create "$backup_name" --include-namespaces "$NAMESPACE" --wait
    else
      echo "WARNING: CREATE_PREOP_BACKUP=0 on prod-like context '$K8S_CONTEXT_EFFECTIVE' (operator override)"
    fi
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

CANONICAL_BRANDING_FILE="$REPO_ROOT/scripts/tenants/${SLUG}-branding.json"

provision_cmd=(
  "$REPO_ROOT/scripts/tenants/provision-tenant.sh"
  --context "$K8S_CONTEXT_EFFECTIVE"
  --slug "$SLUG"
  --name "$NAME"
  --domain "$DOMAIN"
)
[[ -n "$CONTACT_EMAIL" ]] && provision_cmd+=(--contact-email "$CONTACT_EMAIL")
[[ -n "$COUNTRY" ]] && provision_cmd+=(--country "$COUNTRY")
[[ -f "$CANONICAL_BRANDING_FILE" ]] && provision_cmd+=(--branding-file "$CANONICAL_BRANDING_FILE")
[[ "$DRY_RUN" -eq 1 ]] && provision_cmd+=(--dry-run)

mapping_cmd=(
  "$REPO_ROOT/scripts/tenants/sync-tenant-enterprise-mapping.sh"
  --env "$ENVIRONMENT"
  --context "$K8S_CONTEXT_EFFECTIVE"
  --namespace "$NAMESPACE"
)
if [[ "$ENVIRONMENT" == "staging" ]]; then
  mapping_cmd+=(--canonical-domains)
fi
[[ "$DRY_RUN" -eq 1 ]] && mapping_cmd+=(--dry-run) || mapping_cmd+=(--apply)

idp_cmd=(
  "$REPO_ROOT/scripts/tenants/configure-tenant-idp.sh"
  --env "$ENVIRONMENT"
  --context "$K8S_CONTEXT_EFFECTIVE"
  --namespace "$NAMESPACE"
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
[[ -f "$CANONICAL_BRANDING_FILE" ]] && branding_cmd+=(--branding-file "$CANONICAL_BRANDING_FILE")
[[ "$DRY_RUN" -eq 1 ]] && branding_cmd+=(--dry-run)

echo "[1/6] Provision/reconcile tenant"
if [[ "$DRY_RUN" -eq 1 ]]; then
  "${provision_cmd[@]}"
else
  CONFIRM_PROVISION_TENANT="PROVISION_TENANT" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
    "${provision_cmd[@]}"
fi
echo ""

echo "[2/6] Sync SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping"
if [[ "$DRY_RUN" -eq 1 ]]; then
  "${mapping_cmd[@]}"
else
  CONFIRM_SYNC_TENANT_ENTERPRISE_MAPPING="SYNC_TENANT_ENTERPRISE_MAPPING" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
    "${mapping_cmd[@]}"
fi
echo ""

echo "[3/6] Configure tenant IdP"
if [[ "$DRY_RUN" -eq 1 ]]; then
  "${idp_cmd[@]}"
else
  CONFIRM_CONFIGURE_TENANT_IDP="CONFIGURE_TENANT_IDP" ALLOW_PROD_APPLY="$ALLOW_PROD_APPLY" CREATE_PREOP_BACKUP=0 \
    "${idp_cmd[@]}"
fi
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
      echo "DRY-RUN: would run scripts/tenants/repair-enterprise-schema.sh --env $ENVIRONMENT --context $K8S_CONTEXT_EFFECTIVE --namespace $NAMESPACE"
    fi
    echo "DRY-RUN: would run scripts/qa/verify-enterprise-runtime-app-wiring.sh --env $ENVIRONMENT --context $K8S_CONTEXT_EFFECTIVE --strict"
    echo "DRY-RUN: would run scripts/qa/verify-enterprise-sso-readiness.sh --env $ENVIRONMENT --tenant $SLUG"
    echo "DRY-RUN: would run scripts/qa/verify-multisite-config.sh $ENVIRONMENT"
  else
    if [[ "$RUN_SCHEMA_GUARD" -eq 1 ]]; then
      "$REPO_ROOT/scripts/tenants/repair-enterprise-schema.sh" --env "$ENVIRONMENT" --context "$K8S_CONTEXT_EFFECTIVE" --namespace "$NAMESPACE"
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
