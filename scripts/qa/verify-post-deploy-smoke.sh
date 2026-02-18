#!/usr/bin/env bash
# @covers AC-DEP-204
# @spec: branding-system_spec.md
# verify-post-deploy-smoke.sh — Post-deploy smoke matrix for authn, LMS, Studio, and MFEs
#
# Runs a structured smoke test matrix after a branding/UI/UX deploy.
# Must PASS before marking any rollout complete.
#
# Usage:
#   ./scripts/qa/verify-post-deploy-smoke.sh [--env prod|dev] [--evidence-dir DIR]
#   ./scripts/qa/verify-post-deploy-smoke.sh --env prod --evidence-dir var/evidence/release-20260218

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV="prod"
EVIDENCE_DIR=""
CURL_TIMEOUT="${CURL_TIMEOUT:-10}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="${2:-prod}"; shift 2 ;;
    --evidence-dir) EVIDENCE_DIR="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--env prod|dev] [--evidence-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# ── Domain configuration ────────────────────────────────────────────────────

case "$ENV" in
  prod)
    LMS_DOMAIN="academyv2.mereka.io"
    STUDIO_DOMAIN="studio.academyv2.mereka.io"
    MFE_DOMAIN="apps.academyv2.mereka.io"
    TENANT_DOMAINS=("academy.biji-biji.com" "skillourfuture.academy.mereka.io")
    ;;
  dev)
    LMS_DOMAIN="${LMS_DOMAIN:-localhost}"
    STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.localhost}"
    MFE_DOMAIN="${MFE_DOMAIN:-apps.localhost}"
    TENANT_DOMAINS=()
    ;;
  *) echo "Unknown env: $ENV" >&2; exit 1 ;;
esac

PASS=0
FAIL=0
WARN=0
SKIP=0
RESULTS=()

pass() { PASS=$((PASS + 1)); RESULTS+=("PASS: $1"); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); RESULTS+=("FAIL: $1"); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); RESULTS+=("WARN: $1"); echo "WARN: $1"; }
skip() { SKIP=$((SKIP + 1)); RESULTS+=("SKIP: $1"); echo "SKIP: $1"; }

# HTTP smoke helper: checks status code
smoke_http() {
  local label="$1"
  local url="$2"
  local expected_code="${3:-200}"

  local code
  code="$(curl -so /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "$url" 2>/dev/null || echo "000")"

  if [[ "$code" == "$expected_code" ]]; then
    pass "$label → HTTP $code ($url)"
  elif [[ "$code" == "000" ]]; then
    fail "$label → UNREACHABLE ($url)"
  else
    fail "$label → HTTP $code (expected $expected_code) ($url)"
  fi
}

# MFE config helper: checks key fields in /api/mfe_config/v1
smoke_mfe_config() {
  local label="$1"
  local domain="$2"

  local config
  config="$(curl -s --max-time "$CURL_TIMEOUT" "https://$domain/api/mfe_config/v1" 2>/dev/null || echo "")"

  if [[ -z "$config" ]]; then
    fail "$label → MFE config unreachable (https://$domain/api/mfe_config/v1)"
    return
  fi

  local site_name
  site_name="$(echo "$config" | python3 -c "import json,sys; print(json.load(sys.stdin).get('SITE_NAME','MISSING'))" 2>/dev/null || echo "PARSE_ERROR")"

  if [[ "$site_name" == "MISSING" || "$site_name" == "PARSE_ERROR" ]]; then
    fail "$label → SITE_NAME missing or unparseable"
  else
    pass "$label → SITE_NAME='$site_name'"
  fi
}

echo "=== Post-Deploy Smoke Matrix ==="
echo "Environment: $ENV"
echo "LMS: $LMS_DOMAIN | Studio: $STUDIO_DOMAIN | MFE: $MFE_DOMAIN"
echo "Tenant domains: ${TENANT_DOMAINS[*]:-none}"
echo ""

# ── Section 1: LMS Core ─────────────────────────────────────────────────────

echo "--- LMS Core ---"
smoke_http "LMS homepage" "https://$LMS_DOMAIN/"
smoke_http "LMS heartbeat" "https://$LMS_DOMAIN/heartbeat"
smoke_http "LMS MFE config API" "https://$LMS_DOMAIN/api/mfe_config/v1"
smoke_mfe_config "LMS MFE config" "$LMS_DOMAIN"

# ── Section 2: Studio/CMS ───────────────────────────────────────────────────

echo ""
echo "--- Studio/CMS ---"
smoke_http "Studio homepage" "https://$STUDIO_DOMAIN/"
smoke_http "Studio heartbeat" "https://$STUDIO_DOMAIN/heartbeat"

# ── Section 3: Authentication MFE ────────────────────────────────────────────

echo ""
echo "--- Authentication MFE ---"
smoke_http "Authn login" "https://$MFE_DOMAIN/authn/login"
smoke_http "Authn register" "https://$MFE_DOMAIN/authn/register"

# ── Section 4: MFE Routes (at least 3 required per AC-DEP-204) ──────────────

echo ""
echo "--- MFE Routes ---"
smoke_http "Learner Dashboard MFE" "https://$MFE_DOMAIN/learner-dashboard/"
smoke_http "Account Settings MFE" "https://$MFE_DOMAIN/account/"
smoke_http "Profile MFE" "https://$MFE_DOMAIN/profile/u/"
smoke_http "Course About MFE" "https://$MFE_DOMAIN/course-about/"
smoke_http "Discussions MFE" "https://$MFE_DOMAIN/discussions/"

# ── Section 5: Tenant Domain Smoke ───────────────────────────────────────────

echo ""
echo "--- Tenant Domains ---"
if [[ ${#TENANT_DOMAINS[@]} -eq 0 ]]; then
  skip "No tenant domains configured for $ENV"
else
  for domain in "${TENANT_DOMAINS[@]}"; do
    smoke_http "Tenant LMS ($domain)" "https://$domain/"
    smoke_mfe_config "Tenant MFE config ($domain)" "$domain"
  done
fi

# ── Section 6: K8s Pod Readiness (if kubectl available) ──────────────────────

echo ""
echo "--- K8s Pod Readiness ---"
if command -v kubectl &>/dev/null; then
  for deploy in lms cms mfe; do
    READY="$(kubectl get deploy "$deploy" -n mereka-lms -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")"
    DESIRED="$(kubectl get deploy "$deploy" -n mereka-lms -o jsonpath='{.status.replicas}' 2>/dev/null || echo "")"
    if [[ -n "$READY" && "$READY" == "$DESIRED" && "$READY" -gt 0 ]]; then
      pass "K8s $deploy: $READY/$DESIRED ready"
    elif [[ -z "$READY" ]]; then
      warn "K8s $deploy: could not query (cluster unreachable?)"
    else
      fail "K8s $deploy: $READY/$DESIRED ready"
    fi
  done
else
  skip "kubectl not available — skipping pod readiness checks"
fi

# ── Section 7: Image Tag Verification (if kubectl available) ─────────────────

echo ""
echo "--- Running Image Tags ---"
if command -v kubectl &>/dev/null; then
  for deploy in lms cms mfe; do
    IMAGE="$(kubectl get deploy "$deploy" -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")"
    if [[ -n "$IMAGE" ]]; then
      TAG="${IMAGE##*:}"
      if [[ "$TAG" == "latest" ]]; then
        warn "K8s $deploy image uses 'latest' tag: $IMAGE"
      else
        pass "K8s $deploy image: $IMAGE"
      fi
    else
      warn "K8s $deploy: could not read image tag"
    fi
  done
else
  skip "kubectl not available — skipping image tag checks"
fi

# ── Evidence Output ──────────────────────────────────────────────────────────

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP ==="

if [[ -n "$EVIDENCE_DIR" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  EVIDENCE_FILE="$EVIDENCE_DIR/post-deploy-smoke.log"
  {
    echo "# Post-Deploy Smoke Matrix"
    echo "# Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Environment: $ENV"
    echo "# Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN SKIP=$SKIP"
    echo ""
    printf '%s\n' "${RESULTS[@]}"
  } > "$EVIDENCE_FILE"
  echo "Evidence written to: $EVIDENCE_FILE"
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — do NOT mark rollout as complete"
  exit 1
fi

echo "RESULT: PASS — rollout may proceed"
exit 0
