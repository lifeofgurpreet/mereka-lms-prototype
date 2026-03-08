#!/usr/bin/env bash
# @covers AC-RKE2-006, AC-RKE2-007, AC-RKE2-009, AC-RKE2-011, AC-RKE2-013
# @spec: k8s-deployment_spec.md
#
# verify-migration-completion-plan.sh
#
# Verifies that the RKE2 LMS migration completion plan is complete,
# machine-checkable, and all referenced resources are in place.
#
# Offline mode (default): checks that migration plan docs exist, DNS
#   records are documented, rollback procedures are defined, and all
#   referenced K8s manifests are present.
#
# Online mode: verifies DNS resolution, certificate validity, and
#   service health endpoints for the staging environment.
#
# Modes:
#   --offline     Source-only checks (no network or kubectl required). Default.
#   --online      DNS resolution, SSL cert validity, service health endpoints.
#   --context X   kubectl context to use (default: rke2-nonprod)
#   --namespace X K8s namespace (default: mereka-lms)
#
# Usage:
#   scripts/qa/verify-migration-completion-plan.sh --offline
#   scripts/qa/verify-migration-completion-plan.sh --online
#   scripts/qa/verify-migration-completion-plan.sh --online --context rke2-nonprod

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0
SKIP=0

pass_check() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip_check() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Parse args
MODE=offline
KUBECONTEXT="${KUBECONTEXT:-rke2-nonprod}"
NS="${NS:-mereka-lms}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline)    MODE=offline;       shift ;;
    --online)     MODE=online;        shift ;;
    --context)    KUBECONTEXT="$2";   shift 2 ;;
    --namespace)  NS="$2";            shift 2 ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [--offline|--online] [--context CTX] [--namespace NS]

Modes:
  --offline   Static checks (docs, manifests, rollback procedure) — default
  --online    DNS resolution, SSL certificate validity, service health endpoints

Environment overrides:
  KUBECONTEXT   kubectl context  (default: rke2-nonprod)
  NS            K8s namespace    (default: mereka-lms)
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; echo "Run with --help for usage." >&2; exit 1 ;;
  esac
done

KC() { kubectl --context "$KUBECONTEXT" "$@"; }

# Staging domain constants
LMS_DOMAIN="academyv2.mereka.dev"
STUDIO_DOMAIN="studio.academyv2.mereka.dev"
MFE_DOMAIN="apps.academyv2.mereka.dev"

# Key paths
PLAN_DOC="$REPO_ROOT/docs/status/migrations/RKE2_MIGRATION_PLAN.md"
HANDOFF_DOC="$REPO_ROOT/reports/2026/closures/RKE2_LMS_HANDOFF.md"
ROLLOUT_MATRIX="$REPO_ROOT/docs/status/migrations/RKE2_ROLLOUT_MATRIX.md"
CF_DNS_DOC="$REPO_ROOT/docs/operations/CLOUDFLARE_DNS.md"
RKE2_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/rke2-nonprod"
BASE_SECRETS="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"

echo "========================================================"
echo "RKE2 Migration Completion Plan Verifier"
echo "  mode=$MODE  context=$KUBECONTEXT  ns=$NS"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 1 — Migration plan documents exist and are complete
# -----------------------------------------------------------------------
echo "--- [1/6] Migration Plan Documentation ---"

# Migration plan doc exists
if [[ -f "$PLAN_DOC" ]]; then
  pass_check "RKE2_MIGRATION_PLAN.md exists"
else
  fail_check "RKE2_MIGRATION_PLAN.md missing at $PLAN_DOC"
fi

# Handoff doc exists
if [[ -f "$HANDOFF_DOC" ]]; then
  pass_check "RKE2_LMS_HANDOFF.md exists"
else
  fail_check "RKE2_LMS_HANDOFF.md missing at $HANDOFF_DOC"
fi

# Rollout matrix exists
if [[ -f "$ROLLOUT_MATRIX" ]]; then
  pass_check "RKE2_ROLLOUT_MATRIX.md exists"
else
  fail_check "RKE2_ROLLOUT_MATRIX.md missing at $ROLLOUT_MATRIX"
fi

# Cloudflare DNS doc exists
if [[ -f "$CF_DNS_DOC" ]]; then
  pass_check "CLOUDFLARE_DNS.md exists"
else
  fail_check "CLOUDFLARE_DNS.md missing at $CF_DNS_DOC"
fi

# Migration plan covers required sections
if [[ -f "$PLAN_DOC" ]]; then
  required_sections=(
    "Pre-Migration Checklist"
    "DNS Cutover Procedure"
    "Rollback Criteria"
    "Post-Cutover Verification"
    "On-Call Schedule"
  )
  for section in "${required_sections[@]}"; do
    if grep -q "$section" "$PLAN_DOC"; then
      pass_check "Migration plan contains section: $section"
    else
      fail_check "Migration plan missing section: $section"
    fi
  done
fi

echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 2 — DNS records are documented
# -----------------------------------------------------------------------
echo "--- [2/6] DNS Records Documentation ---"

# Migration plan documents the staging domain
if [[ -f "$PLAN_DOC" ]]; then
  for domain in "academyv2.mereka.dev" "studio.academyv2.mereka.dev" "apps.academyv2.mereka.dev"; do
    if grep -q "$domain" "$PLAN_DOC"; then
      pass_check "Migration plan documents DNS record for $domain"
    else
      fail_check "Migration plan missing DNS record for $domain"
    fi
  done

  # Plan documents DNS rollback procedure
  if grep -q "Rollback\|rollback" "$PLAN_DOC" && grep -q "cloudflare\|Cloudflare\|dns_records" "$PLAN_DOC"; then
    pass_check "Migration plan documents DNS rollback procedure"
  else
    fail_check "Migration plan missing DNS rollback procedure"
  fi

  # Plan specifies proxy:off (required for cert-manager ACME challenges)
  if grep -qi "gray cloud\|proxied.*false\|proxy.*off\|DNS.only" "$PLAN_DOC"; then
    pass_check "Migration plan specifies Cloudflare proxy=off (required for ACME)"
  else
    fail_check "Migration plan does not specify Cloudflare proxy=off (cert-manager ACME requires DNS-only)"
  fi
fi

# Cloudflare DNS doc references GKE production IP (must not be changed)
if [[ -f "$CF_DNS_DOC" ]]; then
  if grep -q "34.177.83.168\|GKE" "$CF_DNS_DOC"; then
    pass_check "Cloudflare DNS doc references GKE production IP (production baseline documented)"
  else
    skip_check "Cloudflare DNS doc does not reference GKE IP (check manually)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 3 — Rollback procedure is machine-checkable
# -----------------------------------------------------------------------
echo "--- [3/6] Rollback Procedure Validity ---"

if [[ -f "$PLAN_DOC" ]]; then
  # Rollback criteria must include curl-based checks (machine-checkable)
  if grep -q "curl" "$PLAN_DOC"; then
    pass_check "Rollback criteria include curl-based HTTP checks (machine-checkable)"
  else
    fail_check "Rollback criteria lack curl-based HTTP checks"
  fi

  # Rollback criteria include kubectl-based checks
  if grep -q "kubectl" "$PLAN_DOC"; then
    pass_check "Rollback criteria include kubectl-based cluster checks"
  else
    fail_check "Rollback criteria lack kubectl-based cluster checks"
  fi

  # Rollback time bound is specified
  if grep -qi "5 min\|< 5\|within.*min\|minutes" "$PLAN_DOC"; then
    pass_check "Rollback procedure specifies time bound"
  else
    fail_check "Rollback procedure missing time bound (should specify expected RTO)"
  fi

  # Decision deadline is documented
  if grep -qi "30 min\|decision\|deadline" "$PLAN_DOC"; then
    pass_check "Rollback decision deadline documented"
  else
    fail_check "Rollback decision deadline not documented"
  fi

  # R1–R8 rollback signals are enumerated
  if grep -q "R1\|R2\|R3" "$PLAN_DOC"; then
    rollback_count=$(grep -c '^| R[0-9]' "$PLAN_DOC" || true)
    if [[ "$rollback_count" -ge 5 ]]; then
      pass_check "Rollback criteria table has $rollback_count machine-checkable signals"
    else
      fail_check "Rollback criteria table has only $rollback_count signals (expected >= 5)"
    fi
  else
    fail_check "Rollback criteria table (R1..Rn) not found in migration plan"
  fi

  # Verify the verification script itself is referenced in the plan
  if grep -q "verify-migration-completion-plan.sh" "$PLAN_DOC"; then
    pass_check "Migration plan references this verification script"
  else
    fail_check "Migration plan does not reference verify-migration-completion-plan.sh"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 4 — K8s manifests exist
# -----------------------------------------------------------------------
echo "--- [4/6] Required K8s Manifests ---"

# rke2-nonprod overlay exists
if [[ -d "$RKE2_OVERLAY" ]]; then
  pass_check "rke2-nonprod overlay directory exists"
else
  fail_check "rke2-nonprod overlay missing at $RKE2_OVERLAY"
fi

# Required overlay files
overlay_files=(
  "$RKE2_OVERLAY/kustomization.yaml:rke2-nonprod kustomization.yaml"
  "$RKE2_OVERLAY/patches/externalsecrets-infisical.yaml:externalsecrets-infisical.yaml patch"
  "$BASE_SECRETS:base external-secrets.yaml"
)

for entry in "${overlay_files[@]}"; do
  file="${entry%%:*}"
  label="${entry##*:}"
  if [[ -f "$file" ]]; then
    pass_check "$label exists"
  else
    fail_check "$label missing: $file"
  fi
done

# Ingress manifests (required for DNS cutover to route traffic)
for ingress_suffix in lms studio mfe; do
  ingress_file="$RKE2_OVERLAY/ingress-openedx-${ingress_suffix}.yaml"
  if [[ -f "$ingress_file" ]]; then
    pass_check "Ingress manifest exists: ingress-openedx-${ingress_suffix}.yaml"
    # Verify cert-manager annotation
    if grep -q "cert-manager.io/cluster-issuer" "$ingress_file"; then
      pass_check "  ingress-openedx-${ingress_suffix}.yaml has cert-manager annotation"
    else
      fail_check "  ingress-openedx-${ingress_suffix}.yaml missing cert-manager annotation"
    fi
    # Verify letsencrypt-prod issuer
    if grep -q "letsencrypt-prod" "$ingress_file"; then
      pass_check "  ingress-openedx-${ingress_suffix}.yaml uses letsencrypt-prod"
    else
      fail_check "  ingress-openedx-${ingress_suffix}.yaml not using letsencrypt-prod"
    fi
  else
    fail_check "Ingress manifest missing: $ingress_file"
  fi
done

# Infisical patch uses infisical-secret-store (not gcp-secret-manager)
infisical_patch="$RKE2_OVERLAY/patches/externalsecrets-infisical.yaml"
if [[ -f "$infisical_patch" ]]; then
  gcp_refs=$(grep -v '^\s*#' "$infisical_patch" | grep -c 'gcp-secret-manager' || true)
  infisical_refs=$(grep -v '^\s*#' "$infisical_patch" | grep -c 'infisical-secret-store' || true)
  if [[ "$infisical_refs" -ge 1 && "$gcp_refs" -eq 0 ]]; then
    pass_check "Infisical patch uses infisical-secret-store exclusively"
  else
    fail_check "Infisical patch: infisical_refs=$infisical_refs, gcp_refs=$gcp_refs (expected >=1 and 0)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# OFFLINE: Section 5 — On-call schedule and pre-migration checklist
# -----------------------------------------------------------------------
echo "--- [5/6] On-Call and Pre-Migration Checklist ---"

if [[ -f "$PLAN_DOC" ]]; then
  # On-call schedule has roles defined
  if grep -qi "Platform Lead\|LMS Engineer\|On-Call" "$PLAN_DOC"; then
    pass_check "On-call schedule defines named roles"
  else
    fail_check "On-call schedule missing named roles"
  fi

  # Recommended cutover window is specified
  if grep -qi "10:00\|SGT\|UTC\|cutover window\|Recommended" "$PLAN_DOC"; then
    pass_check "Recommended cutover window documented"
  else
    fail_check "Cutover window not documented"
  fi

  # Pre-migration checklist exists and has gate items
  if grep -q "Pre-Migration Checklist" "$PLAN_DOC" && grep -q "Gate" "$PLAN_DOC"; then
    pass_check "Pre-migration checklist references deployment gates"
  else
    fail_check "Pre-migration checklist does not reference deployment gates"
  fi

  # Change freeze is mentioned
  if grep -qi "freeze\|no.*deploy\|production.*deploy" "$PLAN_DOC"; then
    pass_check "Change freeze window policy documented"
  else
    fail_check "Change freeze policy not documented"
  fi

  # MongoDB Atlas note (not migrated)
  if grep -qi "Atlas\|MongoDB.*not migrated\|MongoDB.*separate\|MongoDB.*staging" "$PLAN_DOC"; then
    pass_check "MongoDB Atlas staging arrangement documented (Atlas stays, separate staging DB)"
  else
    fail_check "MongoDB Atlas staging arrangement not documented"
  fi

  # Purchase Gateway referenced (not Oscar)
  if grep -qi "Purchase Gateway\|purchase.gateway" "$PLAN_DOC"; then
    pass_check "Purchase Gateway (not Oscar) referenced in migration plan"
  else
    fail_check "Migration plan should reference Purchase Gateway as ecommerce solution"
  fi

  # Forum v2 in-process note
  if grep -qi "Forum v2\|forum.*in.process\|in-process" "$PLAN_DOC"; then
    pass_check "Forum v2 in-process deployment noted"
  else
    skip_check "Forum v2 in-process note not found (check migration plan for forum section)"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# ONLINE: Section 6 — DNS resolution, SSL, service health
# -----------------------------------------------------------------------
echo "--- [6/6] Live Verification ---"

if [[ "$MODE" != "online" ]]; then
  skip_check "[online] DNS resolution check (requires --online)"
  skip_check "[online] SSL certificate validity (requires --online)"
  skip_check "[online] LMS service health (requires --online)"
  skip_check "[online] Studio service health (requires --online)"
  skip_check "[online] MFE service health (requires --online)"
  skip_check "[online] K8s pod health (requires --online)"
  skip_check "[online] ExternalSecrets sync status (requires --online)"
else
  # DNS resolution
  if command -v dig >/dev/null 2>&1; then
    for domain in "$LMS_DOMAIN" "$STUDIO_DOMAIN" "$MFE_DOMAIN"; do
      resolved=$(dig +short "$domain" 2>/dev/null | head -1 || true)
      if [[ -n "$resolved" ]]; then
        pass_check "[online] DNS resolves $domain -> $resolved"
      else
        fail_check "[online] DNS does not resolve $domain (DNS records not yet created)"
      fi
    done
  else
    skip_check "[online] dig not available — skipping DNS resolution checks"
  fi

  # SSL certificate validity and expiry
  if command -v curl >/dev/null 2>&1; then
    # Test strict TLS (no -k flag) — failure = cert invalid
    lms_strict=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")
    if [[ "$lms_strict" != "000" ]]; then
      pass_check "[online] SSL certificate valid for $LMS_DOMAIN (strict TLS)"
    else
      # Distinguish SSL error from DNS/connectivity
      lms_insecure=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")
      if [[ "$lms_insecure" != "000" ]]; then
        fail_check "[online] SSL certificate INVALID for $LMS_DOMAIN (curl -k works but strict fails — cert not trusted)"
      else
        fail_check "[online] $LMS_DOMAIN unreachable (DNS not propagated or RKE2 ingress not ready)"
      fi
    fi

    # Check cert expiry via openssl
    if command -v openssl >/dev/null 2>&1; then
      cert_expiry=$(echo \
        | openssl s_client -connect "${LMS_DOMAIN}:443" -servername "${LMS_DOMAIN}" 2>/dev/null \
        | openssl x509 -noout -enddate 2>/dev/null \
        | sed 's/notAfter=//' \
        || echo "")
      if [[ -n "$cert_expiry" ]]; then
        expiry_epoch=$(date -d "$cert_expiry" +%s 2>/dev/null || echo "0")
        now_epoch=$(date +%s)
        days_remaining=$(( (expiry_epoch - now_epoch) / 86400 ))
        if [[ "$days_remaining" -ge 14 ]]; then
          pass_check "[online] SSL cert for $LMS_DOMAIN valid for $days_remaining more days"
        elif [[ "$days_remaining" -ge 0 ]]; then
          fail_check "[online] SSL cert for $LMS_DOMAIN expires in $days_remaining days — renew urgently"
        else
          fail_check "[online] SSL cert for $LMS_DOMAIN has EXPIRED"
        fi
      else
        skip_check "[online] Could not retrieve cert expiry for $LMS_DOMAIN (domain may be unreachable)"
      fi
    else
      skip_check "[online] openssl not available — skipping cert expiry check"
    fi
  else
    skip_check "[online] curl not available — skipping SSL and HTTP checks"
  fi

  # Service health endpoints (rollback criteria R1–R3)
  if command -v curl >/dev/null 2>&1; then
    # R1: LMS homepage
    lms_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${LMS_DOMAIN}/" 2>/dev/null || echo "000")
    if [[ "$lms_status" == "200" || "$lms_status" == "302" ]]; then
      pass_check "[online] LMS homepage https://${LMS_DOMAIN}/ -> HTTP $lms_status (R1: PASS)"
    else
      fail_check "[online] LMS homepage https://${LMS_DOMAIN}/ -> HTTP $lms_status (R1: TRIGGERED — rollback criterion)"
    fi

    # R2: Studio homepage
    studio_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${STUDIO_DOMAIN}/" 2>/dev/null || echo "000")
    if [[ "$studio_status" == "200" || "$studio_status" == "302" ]]; then
      pass_check "[online] Studio https://${STUDIO_DOMAIN}/ -> HTTP $studio_status (R2: PASS)"
    else
      fail_check "[online] Studio https://${STUDIO_DOMAIN}/ -> HTTP $studio_status (R2: TRIGGERED — rollback criterion)"
    fi

    # R3: MFE login
    mfe_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${MFE_DOMAIN}/authn/login" 2>/dev/null || echo "000")
    if [[ "$mfe_status" == "200" || "$mfe_status" == "302" ]]; then
      pass_check "[online] MFE login https://${MFE_DOMAIN}/authn/login -> HTTP $mfe_status (R3: PASS)"
    else
      fail_check "[online] MFE login https://${MFE_DOMAIN}/authn/login -> HTTP $mfe_status (R3: TRIGGERED — rollback criterion)"
    fi

    # R6: LMS heartbeat
    heartbeat_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://${LMS_DOMAIN}/heartbeat" 2>/dev/null || echo "000")
    if [[ "$heartbeat_status" == "200" ]]; then
      pass_check "[online] LMS /heartbeat -> HTTP 200 (R6: PASS)"
    elif [[ "$heartbeat_status" == "404" ]]; then
      skip_check "[online] LMS /heartbeat -> 404 (endpoint may differ; check /health/)"
    else
      fail_check "[online] LMS /heartbeat -> HTTP $heartbeat_status (R6: TRIGGERED — rollback criterion)"
    fi
  fi

  # K8s pod health (R5)
  if command -v kubectl >/dev/null 2>&1; then
    if KC get namespace "$NS" >/dev/null 2>&1; then
      # Check core pods Running
      for pod_label in lms cms caddy; do
        running_count=$(KC get pods -n "$NS" \
          -l "app.kubernetes.io/name=$pod_label" \
          --field-selector=status.phase=Running \
          -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' \
          2>/dev/null | grep -c . || true)
        if [[ "$running_count" -ge 1 ]]; then
          pass_check "[online] $pod_label pod(s) Running in $NS ($running_count pods) (R5: PASS)"
        else
          fail_check "[online] 0 $pod_label pods Running in $NS (R5: TRIGGERED — rollback criterion)"
        fi
      done

      # Check for DB errors in LMS logs (R7)
      lms_pod=$(KC get pods -n "$NS" \
        -l "app.kubernetes.io/name=lms" \
        --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
      if [[ -n "$lms_pod" ]]; then
        db_errors=$(KC logs -n "$NS" "$lms_pod" --tail=100 2>/dev/null \
          | grep -i 'OperationalError\|connection.*refused\|can.t connect.*database\|FATAL.*database' \
          || true)
        if [[ -z "$db_errors" ]]; then
          pass_check "[online] No DB errors in recent LMS logs ($lms_pod) (R7: PASS)"
        else
          fail_check "[online] DB connection errors in LMS logs (R7: TRIGGERED — rollback criterion):"
          echo "$db_errors" | head -5 | sed 's/^/    /'
        fi
      else
        skip_check "[online] No running LMS pod found — cannot check logs for DB errors (R7)"
      fi

      # ExternalSecrets sync status
      es_statuses=$(KC get externalsecret -n "$NS" \
        -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].reason}{"\n"}{end}' \
        2>/dev/null || echo "")
      if [[ -z "$es_statuses" ]]; then
        skip_check "[online] No ExternalSecrets found in $NS (namespace may be empty)"
      else
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          es_name="${line%%=*}"
          es_reason="${line##*=}"
          if [[ "$es_reason" == "SecretSynced" ]]; then
            pass_check "[online] ExternalSecret $es_name: SecretSynced"
          else
            fail_check "[online] ExternalSecret $es_name: ${es_reason:-unknown} (expected SecretSynced)"
          fi
        done <<< "$es_statuses"
      fi

      # Certificate issuance status
      certs=$(KC get certificate -n "$NS" \
        -o jsonpath='{range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' \
        2>/dev/null || echo "")
      if [[ -z "$certs" ]]; then
        skip_check "[online] No Certificate resources found in $NS"
      else
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          cert_name="${line%%=*}"
          cert_ready="${line##*=}"
          if [[ "$cert_ready" == "True" ]]; then
            pass_check "[online] Certificate $cert_name: Ready=True"
          else
            fail_check "[online] Certificate $cert_name: Ready=${cert_ready:-unknown} (SSL cutover blocked until Ready=True)"
          fi
        done <<< "$certs"
      fi
    else
      fail_check "[online] Namespace $NS not found on context $KUBECONTEXT"
    fi
  else
    skip_check "[online] kubectl not available — skipping K8s live checks"
  fi
fi

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo ""
echo "========================================================"
echo "Summary: $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================================"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "RESULT: FAIL — $FAIL check(s) failed"
  echo ""
  echo "Remediation reference:"
  echo "  Migration plan:  docs/status/migrations/RKE2_MIGRATION_PLAN.md"
  echo "  Handoff doc:     reports/2026/closures/RKE2_LMS_HANDOFF.md"
  echo "  Rollout matrix:  docs/status/migrations/RKE2_ROLLOUT_MATRIX.md"
  echo "  DNS docs:        docs/operations/CLOUDFLARE_DNS.md"
  if [[ "$MODE" == "online" ]]; then
    echo ""
    echo "Rollback signals (any triggered = immediate rollback):"
    echo "  R1-R3: HTTP checks — run: curl -s -o /dev/null -w '%{http_code}' https://$LMS_DOMAIN/"
    echo "  R4:    SSL check  — run: curl -s -o /dev/null -w '%{http_code}' https://$LMS_DOMAIN/ (no -k)"
    echo "  R5:    Pod check  — run: kubectl --context $KUBECONTEXT get pods -n $NS"
    echo "  R6:    Heartbeat  — run: curl -s https://$LMS_DOMAIN/heartbeat"
    echo "  R7:    DB logs    — run: kubectl --context $KUBECONTEXT logs -n $NS -l app.kubernetes.io/name=lms --tail=100"
    echo ""
    echo "DNS rollback (< 2 minutes):"
    echo "  Delete Cloudflare A record for academyv2.mereka.dev"
    echo "  Delete Cloudflare CNAMEs for studio.academyv2.mereka.dev, apps.academyv2.mereka.dev"
    echo "  GKE production (academyv2.mereka.io) is unaffected."
  fi
  echo ""
  exit 1
fi

echo ""
echo "RESULT: PASS"
exit 0
