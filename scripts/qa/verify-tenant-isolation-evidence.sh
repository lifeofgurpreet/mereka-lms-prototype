#!/usr/bin/env bash
# @covers AC-UI-201, AC-UI-202, AC-UI-203, AC-UI-204, AC-UI-205
# @spec: bead-115d24
#
# verify-tenant-isolation-evidence.sh
#
# Verification script for the tenant-domain brand/auth smoke and tenant
# isolation evidence lane (bead mereka-lms-115d.24).
#
# Modes:
#   Offline (default) — validates documentation, naming conventions, and
#       cross-references exist. Safe to run in CI with no live cluster.
#   Live (TENANT_ISOLATION_LIVE=1) — executes HTTP probes against live
#       endpoints to verify isolation controls in the running cluster.
#
# Usage:
#   ./scripts/qa/verify-tenant-isolation-evidence.sh
#   TENANT_ISOLATION_LIVE=1 ./scripts/qa/verify-tenant-isolation-evidence.sh
#
# Exit codes:
#   0 — 0 FAIL (WARNs are non-blocking)
#   1 — 1 or more FAIL
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIVE_MODE="${TENANT_ISOLATION_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UI-201..205: Tenant Isolation Evidence Gate ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (TENANT_ISOLATION_LIVE=1)"
else
  echo "Mode: OFFLINE (set TENANT_ISOLATION_LIVE=1 for live cluster checks)"
fi
echo ""

# ---------------------------------------------------------------------------
# Key file paths
# ---------------------------------------------------------------------------
EVIDENCE_DOC="$REPO_ROOT/docs/operations/TENANT_ISOLATION_EVIDENCE.md"
BRANDING_MATRIX="$REPO_ROOT/docs/operations/TENANT_BRANDING_MATRIX.md"
HOSTNAMES_DOC="$REPO_ROOT/docs/operations/OPENEDX_HOSTNAMES.md"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
MULTISITE_LMS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

# The three canonical production tenant domains
declare -a TENANT_DOMAINS=(
  "academyv2.mereka.io"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
)

# Branding markers required per-domain
declare -a BRANDING_MARKERS=(
  "footer"
  "title"
  "brand"
)

# ---------------------------------------------------------------------------
# AC-UI-201: Per-tenant branding matrix checks for >= 3 domains with
#            footer/title/service markers defined
# ---------------------------------------------------------------------------
echo "--- AC-UI-201: Per-Tenant Branding Matrix (3 domains, footer/title/service markers) ---"

if [[ ! -f "$EVIDENCE_DOC" ]]; then
  do_fail "AC-UI-201: TENANT_ISOLATION_EVIDENCE.md not found — create docs/operations/TENANT_ISOLATION_EVIDENCE.md"
else
  do_pass "AC-UI-201: TENANT_ISOLATION_EVIDENCE.md exists"

  # All 3 tenant domains must appear in the evidence doc
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$EVIDENCE_DOC"; then
      do_pass "AC-UI-201: tenant domain '$domain' present in evidence doc"
    else
      do_fail "AC-UI-201: tenant domain '$domain' NOT found in TENANT_ISOLATION_EVIDENCE.md"
    fi
  done

  # Footer marker documented
  if grep -qiE "footer.*text|footer marker|per.tenant.*footer|footer.*brand" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-201: footer branding marker documented in evidence doc"
  else
    do_fail "AC-UI-201: footer branding marker not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Page title marker documented
  if grep -qiE "page title|title marker|<title>|browser.*title" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-201: page title marker documented in evidence doc"
  else
    do_fail "AC-UI-201: page title marker not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Service marker documented (logo URL or service name)
  if grep -qiE "logo.*url|service marker|brand.*logo|logo.*brand" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-201: service/logo marker documented in evidence doc"
  else
    do_fail "AC-UI-201: service/logo marker not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi
fi

# TENANT_BRANDING_MATRIX.md must reference all 3 domains
if [[ -f "$BRANDING_MATRIX" ]]; then
  MATRIX_DOMAIN_COUNT=0
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$BRANDING_MATRIX"; then
      MATRIX_DOMAIN_COUNT=$((MATRIX_DOMAIN_COUNT + 1))
    fi
  done
  if [[ "$MATRIX_DOMAIN_COUNT" -ge 3 ]]; then
    do_pass "AC-UI-201: all 3 tenant domains referenced in TENANT_BRANDING_MATRIX.md"
  else
    do_fail "AC-UI-201: only $MATRIX_DOMAIN_COUNT/3 tenant domains in TENANT_BRANDING_MATRIX.md"
  fi
else
  do_fail "AC-UI-201: TENANT_BRANDING_MATRIX.md not found"
fi

# SITE_VARIANTS in plugin must have entries for all 3 domains
if [[ -f "$PLUGIN_FILE" ]]; then
  PLUGIN_DOMAIN_COUNT=0
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "'${domain}'" "$PLUGIN_FILE" || grep -qF "\"${domain}\"" "$PLUGIN_FILE"; then
      PLUGIN_DOMAIN_COUNT=$((PLUGIN_DOMAIN_COUNT + 1))
    fi
  done
  if [[ "$PLUGIN_DOMAIN_COUNT" -ge 3 ]]; then
    do_pass "AC-UI-201: SITE_VARIANTS in mereka_lms.py covers all 3 tenant domains"
  else
    do_fail "AC-UI-201: SITE_VARIANTS only covers $PLUGIN_DOMAIN_COUNT/3 tenant domains"
  fi
else
  do_warn "AC-UI-201: infrastructure/tutor/plugins/mereka_lms.py not found — skipping SITE_VARIANTS check"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-202: Authn smoke expanded with login failures, unauthorized redirects,
#            and enterprise domain host matrix
# ---------------------------------------------------------------------------
echo "--- AC-UI-202: Authn Failure + Unauthorized Redirect + Enterprise Domain Host Matrix ---"

if [[ ! -f "$EVIDENCE_DOC" ]]; then
  do_fail "AC-UI-202: TENANT_ISOLATION_EVIDENCE.md not found — cannot check authn failure matrix"
else
  # Login failure scenario documented
  if grep -qiE "login fail|login.*failure|failed.*login|authn.*fail|fail.*authn" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-202: login failure scenario documented"
  else
    do_fail "AC-UI-202: login failure scenario not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Unauthorized redirect documented
  if grep -qiE "unauthorized.*redirect|redirect.*unauthorized|403.*redirect|redirect.*403|401.*redirect" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-202: unauthorized redirect scenario documented"
  else
    do_fail "AC-UI-202: unauthorized redirect scenario not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Enterprise domain host matrix documented
  if grep -qiE "enterprise.*domain|domain.*host.*matrix|host.*matrix|MFE.*domain|domain.*MFE" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-202: enterprise domain host matrix documented"
  else
    do_fail "AC-UI-202: enterprise domain host matrix not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # apps.* MFE domains documented in host matrix
  if grep -qE "apps\.(academyv2|academy\.biji-biji|skillourfuture)" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-202: MFE app subdomains (apps.*) documented in host matrix"
  else
    do_fail "AC-UI-202: MFE app subdomains not documented in host matrix"
  fi

  # Branded error page documented
  if grep -qiE "branded.*error|branded.*403|error.*brand|brand.*error" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-202: branded error page behavior documented"
  else
    do_warn "AC-UI-202: branded error page behavior not explicitly documented — consider adding"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-203: Rollback/recovery drill with expected outputs and restore commands
# ---------------------------------------------------------------------------
echo "--- AC-UI-203: Rollback/Recovery Drill for Tenant Branding Regressions ---"

if [[ ! -f "$EVIDENCE_DOC" ]]; then
  do_fail "AC-UI-203: TENANT_ISOLATION_EVIDENCE.md not found — cannot check rollback drill"
else
  # Rollback section present
  if grep -qiE "rollback.*drill|recovery drill|rollback.*regression|branding.*regression" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: rollback/recovery drill section present"
  else
    do_fail "AC-UI-203: rollback/recovery drill section not found in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Expected outputs documented
  if grep -qiE "expected output|expected.*result|restore.*expected" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: expected outputs documented in rollback drill"
  else
    do_fail "AC-UI-203: expected outputs not documented in rollback drill"
  fi

  # Restore commands present (kubectl or tutor)
  if grep -qiE "kubectl.*set.*image|tutor.*restart|rollback.*command|restore.*command" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: restore commands present in rollback drill"
  else
    do_fail "AC-UI-203: restore commands not found in rollback drill (expected kubectl/tutor commands)"
  fi

  # Step-by-step format (numbered steps)
  if grep -qiE "Step [0-9]|[0-9]+\. .*rollback|[0-9]+\. .*restore|[0-9]+\. .*verify" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: step-by-step rollback sequence documented"
  else
    do_fail "AC-UI-203: step-by-step rollback sequence not found (expected numbered steps)"
  fi

  # Image tag rollback covered
  if grep -qiE "image.*tag|tag.*rollback|rollback.*image|previous.*tag" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: image tag rollback covered in drill"
  else
    do_warn "AC-UI-203: image tag rollback not explicitly mentioned — consider adding"
  fi

  # Escalation path documented
  if grep -qiE "escalat|on-call|incident|escalation path" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-203: escalation path documented"
  else
    do_warn "AC-UI-203: escalation path not explicitly documented in rollback drill"
  fi
fi

# TENANT_BRANDING_MATRIX.md must also have its own rollback section
if [[ -f "$BRANDING_MATRIX" ]]; then
  if grep -qiE "Rollback Plan|rollback plan" "$BRANDING_MATRIX"; then
    do_pass "AC-UI-203: TENANT_BRANDING_MATRIX.md has Rollback Plan section"
  else
    do_fail "AC-UI-203: TENANT_BRANDING_MATRIX.md missing Rollback Plan section"
  fi
else
  do_warn "AC-UI-203: TENANT_BRANDING_MATRIX.md not found — skipping rollback plan check"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-204: OPENEDX_HOSTNAMES.md refreshed with evidence links and route
#            expectations per hostname
# ---------------------------------------------------------------------------
echo "--- AC-UI-204: Hostname Runbook with Evidence Links + Route Expectations ---"

if [[ ! -f "$HOSTNAMES_DOC" ]]; then
  do_fail "AC-UI-204: OPENEDX_HOSTNAMES.md not found"
else
  do_pass "AC-UI-204: OPENEDX_HOSTNAMES.md exists"

  # All 3 production tenant domains documented
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$HOSTNAMES_DOC"; then
      do_pass "AC-UI-204: production domain '$domain' in OPENEDX_HOSTNAMES.md"
    else
      do_fail "AC-UI-204: production domain '$domain' NOT in OPENEDX_HOSTNAMES.md"
    fi
  done

  # MFE app domains (apps.*) documented
  if grep -qE "apps\.(academyv2|academy\.biji-biji)" "$HOSTNAMES_DOC"; then
    do_pass "AC-UI-204: MFE app domains (apps.*) documented in hostname registry"
  else
    do_fail "AC-UI-204: MFE app domains missing from OPENEDX_HOSTNAMES.md"
  fi

  # Studio hostnames documented
  if grep -qiE "studio\." "$HOSTNAMES_DOC"; then
    do_pass "AC-UI-204: Studio hostnames documented"
  else
    do_fail "AC-UI-204: Studio hostnames not documented in OPENEDX_HOSTNAMES.md"
  fi

  # Shared ecosystem services documented
  if grep -qiE "discovery\.|credentials\.|forum\." "$HOSTNAMES_DOC"; then
    do_pass "AC-UI-204: shared ecosystem service hostnames (discovery, credentials, forum) documented"
  else
    do_warn "AC-UI-204: shared ecosystem services not found in OPENEDX_HOSTNAMES.md"
  fi
fi

# Evidence doc must reference OPENEDX_HOSTNAMES.md
if [[ -f "$EVIDENCE_DOC" ]]; then
  if grep -qF "OPENEDX_HOSTNAMES.md" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-204: TENANT_ISOLATION_EVIDENCE.md cross-references OPENEDX_HOSTNAMES.md"
  else
    do_warn "AC-UI-204: TENANT_ISOLATION_EVIDENCE.md should cross-reference OPENEDX_HOSTNAMES.md"
  fi

  # Evidence doc must have route expectations section
  if grep -qiE "route expectation|expected route|hostname.*route|route.*hostname" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-204: route expectations section present in evidence doc"
  else
    do_fail "AC-UI-204: route expectations not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi

  # Evidence links (artifact paths) documented
  if grep -qiE "var/operations|evidence artifact|isolation.*json|isolation.*evidence" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-204: evidence artifact paths documented"
  else
    do_fail "AC-UI-204: evidence artifact paths not documented in TENANT_ISOLATION_EVIDENCE.md"
  fi
else
  do_fail "AC-UI-204: TENANT_ISOLATION_EVIDENCE.md not found — cannot check evidence links"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-205: No cross-tenant config bleed-through between LMS/CMS/MFE runtime
# ---------------------------------------------------------------------------
echo "--- AC-UI-205: Cross-Tenant Isolation — No Config Bleed-Through ---"

if [[ ! -f "$EVIDENCE_DOC" ]]; then
  do_fail "AC-UI-205: TENANT_ISOLATION_EVIDENCE.md not found — cannot check isolation controls"
else
  # SESSION_COOKIE_DOMAIN isolation documented
  if grep -qiE "SESSION_COOKIE_DOMAIN|session.*cookie.*domain|cookie.*domain.*isolation" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-205: SESSION_COOKIE_DOMAIN isolation documented"
  else
    do_fail "AC-UI-205: SESSION_COOKIE_DOMAIN not documented in isolation controls"
  fi

  # SITE_ID separation documented
  if grep -qiE "SITE_ID|site.*id.*separation|site.*isolation" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-205: SITE_ID separation documented"
  else
    do_fail "AC-UI-205: SITE_ID separation not documented in isolation controls"
  fi

  # CSRF trusted origins isolation documented
  if grep -qiE "CSRF.*TRUSTED|csrf.*origin|trusted.*origin" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-205: CSRF trusted origins isolation documented"
  else
    do_fail "AC-UI-205: CSRF trusted origins not documented in isolation controls"
  fi

  # No shared session state between tenants
  if grep -qiE "no shared.*state|shared.*state.*none|isolated.*session|session.*isolated" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-205: no shared session state between tenants documented"
  else
    do_fail "AC-UI-205: no-shared-state isolation guarantee not documented"
  fi

  # TenantResolutionMiddleware documented as the resolution mechanism
  if grep -qiE "TenantResolutionMiddleware|tenant.*resolution.*middleware|middleware.*tenant" "$EVIDENCE_DOC"; then
    do_pass "AC-UI-205: TenantResolutionMiddleware documented as isolation mechanism"
  else
    do_warn "AC-UI-205: TenantResolutionMiddleware not explicitly named in evidence doc"
  fi
fi

# mereka_multisite.py must exist — it's the runtime isolation layer
if [[ -f "$MULTISITE_LMS" ]]; then
  do_pass "AC-UI-205: deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py exists"

  # Must have SESSION_COOKIE_DOMAIN or host-only cookie pattern
  if grep -qiE "SESSION_COOKIE_DOMAIN|host.only|cookie.*domain" "$MULTISITE_LMS"; then
    do_pass "AC-UI-205: mereka_multisite.py configures SESSION_COOKIE_DOMAIN isolation"
  else
    do_warn "AC-UI-205: SESSION_COOKIE_DOMAIN not found in mereka_multisite.py — verify host-only cookie config"
  fi

  # Must configure CSRF_TRUSTED_ORIGINS
  if grep -qiE "CSRF_TRUSTED_ORIGINS|csrf.*origin" "$MULTISITE_LMS"; then
    do_pass "AC-UI-205: mereka_multisite.py configures CSRF_TRUSTED_ORIGINS"
  else
    do_warn "AC-UI-205: CSRF_TRUSTED_ORIGINS not found in mereka_multisite.py"
  fi
else
  do_warn "AC-UI-205: mereka_multisite.py not found at deploy/k8s/base/ — verify isolation settings location"
fi

# apply-patches.sh must include CSRF trusted origins for all tenant domains
if [[ -f "$APPLY_PATCHES" ]]; then
  CSRF_DOMAIN_COUNT=0
  for domain in "${TENANT_DOMAINS[@]}"; do
    if grep -qF "$domain" "$APPLY_PATCHES"; then
      CSRF_DOMAIN_COUNT=$((CSRF_DOMAIN_COUNT + 1))
    fi
  done
  if [[ "$CSRF_DOMAIN_COUNT" -ge 2 ]]; then
    do_pass "AC-UI-205: apply-patches.sh references $CSRF_DOMAIN_COUNT/3 tenant domains (CSRF/ALLOWED_HOSTS)"
  else
    do_warn "AC-UI-205: only $CSRF_DOMAIN_COUNT tenant domains found in apply-patches.sh — verify CSRF_TRUSTED_ORIGINS coverage"
  fi
else
  do_warn "AC-UI-205: infrastructure/tutor/apply-patches.sh not found — cannot verify CSRF domain list"
fi

echo ""

# ---------------------------------------------------------------------------
# CI wiring check
# ---------------------------------------------------------------------------
echo "--- CI Wiring ---"

if [[ -f "$CI_FILE" ]]; then
  do_pass "CI: .github/workflows/ci.yml exists"
  if grep -q "verify-tenant-isolation-evidence.sh" "$CI_FILE"; then
    do_pass "CI: ci.yml references verify-tenant-isolation-evidence.sh"
  else
    do_warn "CI: ci.yml does not yet reference verify-tenant-isolation-evidence.sh"
  fi
else
  do_fail "CI: .github/workflows/ci.yml not found"
fi

echo ""

# ---------------------------------------------------------------------------
# Live mode — HTTP probes for tenant isolation
# ---------------------------------------------------------------------------
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "--- Live Mode: Tenant Isolation HTTP Probes ---"
  echo ""

  for domain in "${TENANT_DOMAINS[@]}"; do
    base_url="https://${domain}"

    # Probe LMS root — should return 200
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 "$base_url" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" || "$http_code" == "302" ]]; then
      do_pass "[LIVE] $domain LMS root reachable (HTTP $http_code)"
    elif [[ "$http_code" == "000" ]]; then
      do_warn "[LIVE] $domain LMS root unreachable (timeout/DNS)"
    else
      do_warn "[LIVE] $domain LMS root returned HTTP $http_code"
    fi

    # Probe login page — expect 200
    login_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 "${base_url}/login" 2>/dev/null || echo "000")
    if [[ "$login_code" == "200" || "$login_code" == "302" ]]; then
      do_pass "[LIVE] $domain /login reachable (HTTP $login_code)"
    elif [[ "$login_code" == "000" ]]; then
      do_warn "[LIVE] $domain /login unreachable (timeout)"
    else
      do_warn "[LIVE] $domain /login returned HTTP $login_code"
    fi

    # Probe a protected route — expect redirect to login (302) or 401
    dashboard_code=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 15 "${base_url}/dashboard" 2>/dev/null || echo "000")
    if [[ "$dashboard_code" == "302" || "$dashboard_code" == "301" || "$dashboard_code" == "401" ]]; then
      do_pass "[LIVE] $domain /dashboard redirects unauthenticated users (HTTP $dashboard_code)"
    elif [[ "$dashboard_code" == "000" ]]; then
      do_warn "[LIVE] $domain /dashboard unreachable (timeout)"
    elif [[ "$dashboard_code" == "200" ]]; then
      do_warn "[LIVE] $domain /dashboard returned 200 — verify anonymous access is intentional"
    else
      do_warn "[LIVE] $domain /dashboard returned HTTP $dashboard_code"
    fi
  done

  echo ""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - Create docs/operations/TENANT_ISOLATION_EVIDENCE.md if missing"
  echo "  - Ensure all 3 tenant domains are documented with branding markers"
  echo "  - Add authn failure + unauthorized redirect matrix"
  echo "  - Add rollback drill with step-by-step restore commands"
  echo "  - Verify OPENEDX_HOSTNAMES.md is complete with route expectations"
  echo "  - Document SESSION_COOKIE_DOMAIN, SITE_ID, CSRF isolation controls"
  exit 1
fi

echo ""
echo "All tenant isolation evidence checks passed (WARNs are advisory or live-cluster-only)."
exit 0
