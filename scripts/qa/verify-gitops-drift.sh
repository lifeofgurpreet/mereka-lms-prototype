#!/usr/bin/env bash
# @covers AC-DEP-004
# @spec: branding-system_spec.md
# verify-gitops-drift.sh — Check for drift between source repo and GitOps overlays.
#
# Validates that the bbi-infrastructure GitOps overlay reflects the same custom apps,
# middleware, and image tag structure as the source (mereka-lms) repo. Prevents silent
# patch drift between source settings and the overlay applied to the live cluster.
#
# Usage:
#   ./scripts/qa/verify-gitops-drift.sh [--strict]
#
# Options:
#   --strict   Exit 1 on WARN in addition to FAIL (useful in CI)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    -h|--help)
      sed -n '/^# Usage/,/^[^#]/p' "$0" | head -n -1 | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Auto-detect bbi-infrastructure repo (matches pattern used in verify-gitops-image-overrides.sh)
BBI_INFRA=""
for candidate in \
  /home/gurpreet/projects/k8s/bbi-infrastructure \
  /home/gurpreet/projects/k8s/infrastructure; do
  if [[ -d "$candidate" ]]; then
    BBI_INFRA="$candidate"
    break
  fi
done

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() {
  WARN=$((WARN + 1))
  echo "WARN: $1"
  if [[ "$STRICT" -eq 1 ]]; then
    FAIL=$((FAIL + 1))
  fi
}

echo "=== GitOps Drift Check ==="
echo "Source repo: ${REPO_ROOT}"
echo "GitOps repo: ${BBI_INFRA:-<not found>}"
echo ""

# ── Check 1: bbi-infrastructure repo reachable ───────────────────────────────

if [[ -z "$BBI_INFRA" ]]; then
  warn "bbi-infrastructure repo not found — skipping overlay drift checks"
  echo ""
  echo "=== Summary: PASS=${PASS} FAIL=${FAIL} WARN=${WARN} ==="
  [[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
fi

pass "bbi-infrastructure repo found at ${BBI_INFRA}"

# ── Check 2: Production overlay kustomization.yaml ───────────────────────────

OVERLAY_KUST="${BBI_INFRA}/apps/mereka-lms/overlays/prod/kustomization.yaml"

if [[ ! -f "$OVERLAY_KUST" ]]; then
  fail "Production overlay kustomization.yaml missing: ${OVERLAY_KUST}"
else
  pass "Production overlay kustomization.yaml exists"

  # Extract unique image tags from overlay
  OVERLAY_TAGS="$(grep "newTag:" "$OVERLAY_KUST" 2>/dev/null | awk '{print $2}' | sort -u || true)"
  if [[ -n "$OVERLAY_TAGS" ]]; then
    pass "Image tags defined in overlay"
    echo "  Current overlay image tags:"
    echo "$OVERLAY_TAGS" | sed 's/^/    /'
  else
    warn "No image tags found in overlay kustomization.yaml"
  fi

  # Verify no 'latest' tag in production overlay (AC-DEP-001: exact tags required)
  LATEST_TAGS="$(grep "newTag:.*latest" "$OVERLAY_KUST" 2>/dev/null || true)"
  if [[ -n "$LATEST_TAGS" ]]; then
    fail "Production overlay contains 'latest' tag — exact tag required for AC-DEP-001"
  else
    pass "No 'latest' tag in production overlay"
  fi
fi

# ── Check 3: Source production overlay also has no 'latest' ──────────────────

APP_PROD_KUST="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"

if [[ -f "$APP_PROD_KUST" ]]; then
  if grep -q "newTag:.*latest" "$APP_PROD_KUST" 2>/dev/null; then
    fail "App repo production overlay contains 'latest' tag — exact tag required"
  else
    pass "App repo production overlay uses explicit image tag"
  fi
else
  warn "App repo production overlay not found: ${APP_PROD_KUST}"
fi

# ── Check 4: production-prod.py overlay patch ────────────────────────────────

PROD_PY=""
for candidate in \
  "${BBI_INFRA}/apps/mereka-lms/overlays/prod/patches/production-prod.py" \
  "${BBI_INFRA}/apps/mereka-lms/overlays/prod/production-prod.py"; do
  if [[ -f "$candidate" ]]; then
    PROD_PY="$candidate"
    break
  fi
done

if [[ -z "$PROD_PY" ]]; then
  warn "production-prod.py overlay patch not found (may use a different path in this environment)"
else
  pass "production-prod.py overlay patch found: ${PROD_PY}"

  # Check mereka_tenancy is wired in overlay
  if grep -q "mereka_tenancy" "$PROD_PY" 2>/dev/null; then
    pass "mereka_tenancy present in overlay INSTALLED_APPS"
  else
    fail "mereka_tenancy NOT in overlay INSTALLED_APPS (drift from source)"
  fi

  # Check TenantResolutionMiddleware is wired in overlay
  if grep -q "TenantResolutionMiddleware" "$PROD_PY" 2>/dev/null; then
    pass "TenantResolutionMiddleware present in overlay MIDDLEWARE"
  else
    fail "TenantResolutionMiddleware NOT in overlay MIDDLEWARE (drift from source)"
  fi
fi

# ── Check 5: Source production.py custom app/middleware present ───────────────

SRC_PROD_PY=""
for candidate in \
  "${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "${REPO_ROOT}/infrastructure/tutor/plugins/multi-tenancy/setup.py"; do
  if [[ -f "$candidate" ]]; then
    SRC_PROD_PY="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"
    break
  fi
done

if [[ -n "$SRC_PROD_PY" && -f "$SRC_PROD_PY" ]]; then
  pass "Source production.py found: ${SRC_PROD_PY}"
else
  warn "Source deploy/k8s/base production.py not found — skipping source/overlay comparison"
fi

# ── Check 6: Image tag parity between app overlay and GitOps overlay ─────────

if [[ -f "$APP_PROD_KUST" && -f "$OVERLAY_KUST" ]]; then
  APP_TAG="$(grep "newTag:" "$APP_PROD_KUST" | awk '{print $2}' | sort -u | head -1 || true)"
  INFRA_TAG="$(grep "newTag:" "$OVERLAY_KUST" | awk '{print $2}' | sort -u | head -1 || true)"

  if [[ -z "$APP_TAG" || -z "$INFRA_TAG" ]]; then
    warn "Could not extract image tags for parity comparison (one or both may be empty)"
  elif [[ "$APP_TAG" == "$INFRA_TAG" ]]; then
    pass "Image tag parity: app overlay and GitOps overlay both use '${APP_TAG}'"
  else
    fail "Image tag drift: app overlay='${APP_TAG}' vs GitOps overlay='${INFRA_TAG}' (AC-DEP-004)"
  fi
fi

# ── Check 7: Resource limits patch ───────────────────────────────────────────

RESOURCE_PATCH="${BBI_INFRA}/apps/mereka-lms/overlays/prod/patches/resource-limits.yaml"
if [[ -f "$RESOURCE_PATCH" ]]; then
  pass "Resource limits patch exists"
else
  warn "Resource limits patch not found at expected path: ${RESOURCE_PATCH}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "=== Summary: PASS=${PASS} FAIL=${FAIL} WARN=${WARN} ==="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
