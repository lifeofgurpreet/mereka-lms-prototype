#!/usr/bin/env bash
# verify-oscar-deprecation.sh — Audit the Oscar ecommerce deprecation path.
#
# Scans the repository for all Oscar/legacy-ecommerce references and categorises
# each finding as KEEP (still needed during transition), REMOVE (safe to clean
# up now), or MIGRATE (needs a purchase-gateway equivalent).
#
# @spec: ecommerce-purchase-gateway_spec.md
# @covers AC-027, AC-028, AC-031
#
# Usage:
#   ./scripts/qa/verify-oscar-deprecation.sh           # full scan
#   ./scripts/qa/verify-oscar-deprecation.sh --offline # alias (all checks are offline)
#   ./scripts/qa/verify-oscar-deprecation.sh --help
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ── Colours ────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Counters ───────────────────────────────────────────────────────────────
PASS=0
FAIL=0
SKIP=0

# Category counters
COUNT_KEEP=0
COUNT_REMOVE=0
COUNT_MIGRATE=0

# ── Helpers ────────────────────────────────────────────────────────────────
pass()    { printf "  ${GREEN}[PASS]${NC}  %s\n" "$*";  PASS=$((PASS + 1)); }
fail()    { printf "  ${RED}[FAIL]${NC}  %s\n" "$*";   FAIL=$((FAIL + 1)); }
skip()    { printf "  ${YELLOW}[SKIP]${NC}  %s\n" "$*"; SKIP=$((SKIP + 1)); }

keep()    { printf "  ${CYAN}[KEEP]${NC}    %s\n" "$*";    COUNT_KEEP=$((COUNT_KEEP + 1)); }
remove()  { printf "  ${YELLOW}[REMOVE]${NC}  %s\n" "$*";  COUNT_REMOVE=$((COUNT_REMOVE + 1)); }
migrate() { printf "  ${BLUE}[MIGRATE]${NC} %s\n" "$*"; COUNT_MIGRATE=$((COUNT_MIGRATE + 1)); }
detail()  { printf "            %s\n" "$*"; }

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/verify-oscar-deprecation.sh [--offline] [--help]

Options:
  --offline   No-op flag kept for CLI consistency (all checks are static).
  --help      Show this help.

Exit codes:
  0  All required checks pass (WARNs/KEEP/REMOVE findings do not block).
  1  A FAIL check failed (e.g. purchase-gateway replacement missing).
EOF
}

OFFLINE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) OFFLINE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf "Unknown arg: %s\n" "$1" >&2; usage; exit 1 ;;
  esac
done

# ── Section header ─────────────────────────────────────────────────────────
header() {
  printf "\n${BLUE}══════════════════════════════════════════════════════════\n"
  printf "  %s\n" "$*"
  printf "══════════════════════════════════════════════════════════${NC}\n"
}

# ── grep helper that never fails under set -e ──────────────────────────────
rg_files() {
  # $1 = pattern, remaining args = paths/flags
  grep -rl "$1" "${@:2}" 2>/dev/null \
    | grep -v '\.git' \
    | grep -v 'exports/kajabi' \
    | grep -v '\.pyc$' \
    | grep -v 'worktrees/' \
    || true
}

rg_count() {
  grep -rc "$1" "${@:2}" 2>/dev/null \
    | grep -v '\.git\|exports/kajabi\|\.pyc\|worktrees/' \
    | awk -F: '$2>0{sum+=$2} END{print sum+0}' \
    || echo 0
}

# ══════════════════════════════════════════════════════════════════════════
header "1. Replacement Service (Purchase Gateway)"
# ══════════════════════════════════════════════════════════════════════════

PG_DIR="services/purchase-gateway"

if [[ -d "$PG_DIR" ]]; then
  pass "Purchase Gateway service directory exists ($PG_DIR/)"
else
  fail "Purchase Gateway service directory NOT found at $PG_DIR/"
fi

if [[ -f "$PG_DIR/app/main.py" ]]; then
  pass "Purchase Gateway FastAPI application exists"
else
  fail "Purchase Gateway app/main.py missing"
fi

if [[ -d "$PG_DIR/k8s" ]]; then
  pass "Purchase Gateway K8s manifests directory exists"
else
  fail "Purchase Gateway K8s manifests missing ($PG_DIR/k8s/)"
fi

if [[ -f "$PG_DIR/k8s/deployment.yaml" ]]; then
  pass "Purchase Gateway K8s Deployment manifest present"
else
  fail "Purchase Gateway K8s Deployment manifest missing"
fi

# Check ENABLE_GATEWAY_FULFILLMENT feature flag
if grep -q "ENABLE_GATEWAY_FULFILLMENT" "$PG_DIR/k8s/deployment.yaml" 2>/dev/null; then
  pass "ENABLE_GATEWAY_FULFILLMENT feature flag defined in K8s manifest"
else
  fail "ENABLE_GATEWAY_FULFILLMENT feature flag not found in $PG_DIR/k8s/deployment.yaml"
fi

if grep -q "ENABLE_GATEWAY_FULFILLMENT.*false" "$PG_DIR/k8s/deployment.yaml" 2>/dev/null; then
  keep "ENABLE_GATEWAY_FULFILLMENT defaults to false (dark launch — Oscar still active)"
else
  keep "ENABLE_GATEWAY_FULFILLMENT present; verify its default value before cutover"
fi

# ADR for the deprecation decision
if [[ -f "docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md" ]]; then
  pass "ADR-018 (deprecation decision) documented"
else
  fail "ADR-018 missing — deprecation decision not documented"
fi

# ══════════════════════════════════════════════════════════════════════════
header "2. Oscar K8s Resources (KEEP during transition)"
# ══════════════════════════════════════════════════════════════════════════

# Deployments
ECOM_DEPLOY_COUNT="$(grep -c "name: ecommerce$" deploy/k8s/base/deployments.yml 2>/dev/null || true)"
ECOM_WORKER_COUNT="$(grep -c "name: ecommerce-worker$" deploy/k8s/base/deployments.yml 2>/dev/null || true)"
[[ -n "$ECOM_DEPLOY_COUNT" ]] || ECOM_DEPLOY_COUNT="0"
[[ -n "$ECOM_WORKER_COUNT" ]] || ECOM_WORKER_COUNT="0"

if [[ "$ECOM_DEPLOY_COUNT" -gt 0 ]]; then
  keep "deploy/k8s/base/deployments.yml: ecommerce Deployment (active, needed until AC-027 closes)"
else
  pass "ecommerce Deployment removed from base deployments"
fi

if [[ "$ECOM_WORKER_COUNT" -gt 0 ]]; then
  keep "deploy/k8s/base/deployments.yml: ecommerce-worker Deployment (active, remove after decommission)"
else
  pass "ecommerce-worker Deployment removed from base deployments"
fi

# Service
if grep -q "name: ecommerce$" deploy/k8s/base/services.yml 2>/dev/null; then
  keep "deploy/k8s/base/services.yml: ecommerce Service (required while Deployment is active)"
else
  pass "ecommerce Service removed from base services"
fi

# ConfigMaps (ecommerce-settings, ecommerce-worker-settings)
if grep -q "ecommerce-settings" deploy/k8s/base/kustomization.yaml 2>/dev/null; then
  keep "deploy/k8s/base/kustomization.yaml: ecommerce-settings ConfigMap referenced"
fi

if grep -q "ecommerce-worker-settings" deploy/k8s/base/kustomization.yaml 2>/dev/null; then
  keep "deploy/k8s/base/kustomization.yaml: ecommerce-worker-settings ConfigMap referenced"
fi

# Plugin settings files
if [[ -d "deploy/k8s/base/plugins/ecommerce" ]]; then
  keep "deploy/k8s/base/plugins/ecommerce/ settings directory (needed by running Deployment)"
fi

# ══════════════════════════════════════════════════════════════════════════
header "3. Oscar Secrets (KEEP during transition)"
# ══════════════════════════════════════════════════════════════════════════

SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"
OPENEDX_SECRETS="deploy/k8s/base/secrets/openedx-secrets.yaml"

ECOM_SECRET_KEYS=(
  "ECOMMERCE_SECRET_KEY"
  "ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET"
  "ECOMMERCE_BACKEND_OAUTH2_SECRET"
  "ECOMMERCE_EDX_API_KEY"
  "ECOMMERCE_API_SIGNING_KEY"
  "JWT_SECRET_KEY_ECOMMERCE"
  "MYSQL_ECOMMERCE_PASSWORD"
)

for key in "${ECOM_SECRET_KEYS[@]}"; do
  if grep -q "$key" "$SECRETS_FILE" 2>/dev/null \
    || grep -q "$key" "$OPENEDX_SECRETS" 2>/dev/null; then
    keep "Secret $key present (needed until Oscar Deployment is removed)"
  else
    detail "Secret $key not found (already cleaned up or never present)"
  fi
done

# ══════════════════════════════════════════════════════════════════════════
header "4. Caddy / Ingress Routing (REMOVE after cutover)"
# ══════════════════════════════════════════════════════════════════════════

CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"

if [[ -f "$CADDYFILE" ]]; then
  pass "Caddyfile exists"

  if grep -q "ecommerce" "$CADDYFILE"; then
    remove "Caddyfile: ecommerce routing blocks present (remove after Purchase Gateway cutover)"
    detail "File: $CADDYFILE"
    # Show the specific blocks
    grep -n "ecommerce" "$CADDYFILE" | while IFS= read -r line; do
      detail "  $line"
    done
  else
    pass "Caddyfile: no ecommerce routing blocks"
  fi

  # Check if Purchase Gateway has a Caddy route yet
  if grep -q "payments-gateway\|purchase-gateway\|payments.gateway" "$CADDYFILE"; then
    pass "Caddyfile: Purchase Gateway route present"
  else
    migrate "Caddyfile: no Purchase Gateway route yet — add webhook route (AC-027)"
    detail "Add: http://payments.academyv2.mereka.{io,dev} -> payments-gateway:8080"
  fi
else
  fail "Caddyfile not found at $CADDYFILE"
fi

# Ingress hosts
INGRESS_PROD="deploy/k8s/overlays/production/ingress-openedx-lms.yaml"
if [[ -f "$INGRESS_PROD" ]]; then
  if grep -q "ecommerce.academyv2.mereka.io" "$INGRESS_PROD"; then
    remove "Production ingress: ecommerce.academyv2.mereka.io host still present (remove at decommission)"
    detail "File: $INGRESS_PROD"
  else
    pass "Production ingress: no ecommerce host"
  fi
fi

# DNS / Cloudflare records
CF_PROD="infrastructure/cloudflare/records.json"
CF_DEV="infrastructure/cloudflare/records.mereka-dev.json"

for cf_file in "$CF_PROD" "$CF_DEV"; do
  if [[ -f "$cf_file" ]] && grep -q "ecommerce" "$cf_file"; then
    remove "$cf_file: ecommerce DNS record present (delete after decommission)"
  fi
done

# ══════════════════════════════════════════════════════════════════════════
header "5. LMS Settings (REMOVE after cutover)"
# ══════════════════════════════════════════════════════════════════════════

LMS_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$LMS_SETTINGS" ]]; then
  pass "LMS production settings file exists"

  LMS_ECOM_KEYS=(
    "ECOMMERCE_PUBLIC_URL_ROOT"
    "ECOMMERCE_API_URL"
    "ECOMMERCE_SERVICE_WORKER_USERNAME"
  )

  for key in "${LMS_ECOM_KEYS[@]}"; do
    if grep -q "$key" "$LMS_SETTINGS"; then
      remove "LMS settings: $key still set (remove after Purchase Gateway is the sole payment path)"
      detail "File: $LMS_SETTINGS"
    else
      pass "LMS settings: $key not present"
    fi
  done
else
  skip "LMS production settings not found at expected path"
fi

# ══════════════════════════════════════════════════════════════════════════
header "6. Resource Limits / Production Overlay (REMOVE after decommission)"
# ══════════════════════════════════════════════════════════════════════════

RESOURCE_LIMITS="deploy/k8s/overlays/production/patches/resource-limits.yaml"
if [[ -f "$RESOURCE_LIMITS" ]]; then
  if grep -q "name: ecommerce$" "$RESOURCE_LIMITS"; then
    remove "$RESOURCE_LIMITS: ecommerce resource-limits patch present (remove at decommission)"
  fi
  if grep -q "name: ecommerce-worker$" "$RESOURCE_LIMITS"; then
    remove "$RESOURCE_LIMITS: ecommerce-worker resource-limits patch present (remove at decommission)"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════
header "7. Monitoring / Uptime (REMOVE after decommission)"
# ══════════════════════════════════════════════════════════════════════════

UPTIME_ECOM="infrastructure/monitoring/uptime/prod-ecommerce-https.json"
if [[ -f "$UPTIME_ECOM" ]]; then
  remove "$UPTIME_ECOM: uptime check for legacy ecommerce (delete at decommission)"
fi

DASH="infrastructure/monitoring/dashboards/public-endpoints.json"
if [[ -f "$DASH" ]] && grep -q "ecommerce" "$DASH"; then
  remove "$DASH: Grafana dashboard references ecommerce endpoint (update after decommission)"
fi

CERT_ALERT="infrastructure/monitoring/alerts/https-cert-expiry.json"
if [[ -f "$CERT_ALERT" ]] && grep -q "ecommerce" "$CERT_ALERT"; then
  remove "$CERT_ALERT: cert-expiry alert monitors ecommerce.academyv2.mereka.io (remove at decommission)"
fi

CERT_CRONJOB="infrastructure/k8s/cronjobs/cert-verify-prod.yaml"
if [[ -f "$CERT_CRONJOB" ]] && grep -q "ecommerce" "$CERT_CRONJOB"; then
  remove "$CERT_CRONJOB: cert-verify CronJob checks ecommerce host (remove at decommission)"
fi

AUTH_CRONJOB="infrastructure/k8s/cronjobs/auth-verify-prod.yaml"
if [[ -f "$AUTH_CRONJOB" ]] && grep -q "ecommerce" "$AUTH_CRONJOB"; then
  remove "$AUTH_CRONJOB: auth-verify CronJob includes ecommerce service (remove at decommission)"
fi

# ══════════════════════════════════════════════════════════════════════════
header "8. Tutor Config (KEEP with deprecation notice)"
# ══════════════════════════════════════════════════════════════════════════

CONFIG_EXAMPLE="infrastructure/tutor/config.example.yml"
if [[ -f "$CONFIG_EXAMPLE" ]]; then
  if grep -q "DEPRECATED" "$CONFIG_EXAMPLE" && grep -q "ecommerce" "$CONFIG_EXAMPLE"; then
    keep "$CONFIG_EXAMPLE: ecommerce plugin listed with DEPRECATED notice"
  elif grep -q "ecommerce" "$CONFIG_EXAMPLE"; then
    migrate "$CONFIG_EXAMPLE: ecommerce plugin listed without DEPRECATED notice (add comment)"
  fi
fi

# Tutor README plugin list
TUTOR_README="infrastructure/tutor/README.md"
if [[ -f "$TUTOR_README" ]] && grep -q "ecommerce" "$TUTOR_README"; then
  keep "$TUTOR_README: ecommerce in plugin list (expected, add deprecation note if absent)"
fi

# ══════════════════════════════════════════════════════════════════════════
header "9. Missing Migration Artifacts (MIGRATE — implement for cutover)"
# ══════════════════════════════════════════════════════════════════════════

# decommission script from plan
DECOMMISSION_SCRIPT="scripts/infra/decommission-legacy-ecommerce.sh"
if [[ -f "$DECOMMISSION_SCRIPT" ]]; then
  pass "Decommission script exists ($DECOMMISSION_SCRIPT)"
else
  migrate "Decommission script not yet created ($DECOMMISSION_SCRIPT)"
  detail "Required by AC-028: removes Deployment/Service/DNS/OAuth2 clients"
fi

# migration routing middleware from plan
MIGRATION_MIDDLEWARE="services/purchase-gateway/app/middleware/migration.py"
if [[ -f "$MIGRATION_MIDDLEWARE" ]]; then
  pass "Migration routing middleware exists"
else
  migrate "Migration routing middleware not yet created ($MIGRATION_MIDDLEWARE)"
  detail "Required by AC-027: routes new purchases to gateway, in-flight orders to legacy"
fi

# Caddy route for purchase gateway webhook
PG_CADDY_ROUTE=0
if [[ -f "$CADDYFILE" ]]; then
  grep -q "payments-gateway\|purchase-gateway\|payments.gateway" "$CADDYFILE" && PG_CADDY_ROUTE=1 || true
fi
if [[ "$PG_CADDY_ROUTE" -eq 0 ]]; then
  migrate "Caddyfile: no route for Purchase Gateway webhook external access"
  detail "Add: http://payments.academyv2.mereka.{io,dev} -> payments-gateway:8080/webhooks/stripe/"
fi

# ══════════════════════════════════════════════════════════════════════════
header "10. Reference Count Summary"
# ══════════════════════════════════════════════════════════════════════════

# Exclude: exports/, worktrees/, .git/, .pyc, and this script itself
EXCLUDE_DIRS=(
  "--exclude-dir=.git"
  "--exclude-dir=worktrees"
  "--exclude-dir=exports"
  "--exclude=*.pyc"
  "--exclude=verify-oscar-deprecation.sh"
)

OSCAR_REF_COUNT=$(grep -rli "ecommerce\|oscar\|OSCAR_DEFAULT_CURRENCY" \
  "${EXCLUDE_DIRS[@]}" \
  . 2>/dev/null | wc -l || echo 0)

PG_REF_COUNT=$(grep -rli "purchase.gateway\|purchase_gateway\|payments.gateway\|payments_gateway\|ENABLE_GATEWAY_FULFILLMENT" \
  "${EXCLUDE_DIRS[@]}" \
  . 2>/dev/null | wc -l || echo 0)

printf "\n  Oscar/ecommerce references: ${YELLOW}%d file(s)${NC}\n" "$OSCAR_REF_COUNT"
printf "  Purchase Gateway references: ${GREEN}%d file(s)${NC}\n" "$PG_REF_COUNT"

if [[ "$PG_REF_COUNT" -gt 0 ]]; then
  pass "Purchase Gateway has $PG_REF_COUNT file(s) referencing it (replacement active)"
else
  fail "No Purchase Gateway references found — replacement not yet in place"
fi

# ══════════════════════════════════════════════════════════════════════════
header "Summary"
# ══════════════════════════════════════════════════════════════════════════

printf "\n"
printf "  ${GREEN}PASS${NC}     %d\n" "$PASS"
printf "  ${RED}FAIL${NC}     %d\n" "$FAIL"
printf "  ${YELLOW}SKIP${NC}     %d\n" "$SKIP"
printf "\n"
printf "  Categorised findings:\n"
printf "    ${CYAN}KEEP${NC}     %d  (active during transition — do not remove yet)\n" "$COUNT_KEEP"
printf "    ${YELLOW}REMOVE${NC}   %d  (safe to remove after Purchase Gateway cutover)\n" "$COUNT_REMOVE"
printf "    ${BLUE}MIGRATE${NC}  %d  (needs Purchase Gateway equivalent before removal)\n" "$COUNT_MIGRATE"
printf "\n"

if [[ "$FAIL" -gt 0 ]]; then
  printf "  ${RED}RESULT: FAIL${NC} — %d check(s) failed (replacement service incomplete)\n\n" "$FAIL"
  exit 1
else
  printf "  ${GREEN}RESULT: PASS${NC} — Oscar deprecation path is in expected state.\n"
  printf "  Oscar is still active (transition period). See docs/architecture/OSCAR_DEPRECATION.md\n"
  printf "  for the step-by-step decommission plan.\n\n"
  exit 0
fi
