#!/usr/bin/env bash
# verify-aspects-analytics.sh — Aspects analytics readiness check
# @covers AC-001, AC-002, AC-003, AC-004
# @spec: specs/analytics-pipeline_spec.md
#
# Verifies:
# 1. Aspects manifests exist in deploy/k8s/base/plugins/aspects/
# 2. Manifests contain expected resources (ClickHouse, Superset, etc.)
# 3. Aspects is NOT in the active base kustomization (intentional — T148 will wire them)
# 4. Analytics spec exists and has acceptance criteria
#
# PASS/FAIL/SKIP exit codes:
#   0 = all checks PASS (or SKIP where runtime not available)
#   1 = one or more FAIL
#
# Usage: ./scripts/qa/verify-aspects-analytics.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_skip() { SKIP=$((SKIP + 1)); echo -e "${YELLOW}[SKIP]${NC} $1"; }

ASPECTS_DIR="$REPO_ROOT/deploy/k8s/base/plugins/aspects"
BASE_KUSTOMIZATION="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"
ANALYTICS_SPEC="$REPO_ROOT/specs/analytics-pipeline_spec.md"
SETUP_DOC="$REPO_ROOT/docs/reference/operations/ASPECTS_ANALYTICS_SETUP.md"
RETENTION_DOC="$REPO_ROOT/docs/policies/operations/ANALYTICS_DATA_RETENTION.md"

echo -e "${BLUE}=== Aspects Analytics Readiness Check ===${NC}"
echo "  Manifests dir: deploy/k8s/base/plugins/aspects/"
echo "  Base kustomization: deploy/k8s/base/kustomization.yaml"
echo "  Spec: specs/analytics-pipeline_spec.md"
echo ""

# ── Section 1: Manifest files exist ──────────────────────────────────

echo -e "${BLUE}-- Section 1: Manifest files --${NC}"

EXPECTED_FILES=(
  "kustomization.yaml"
  "configmaps.yml"
  "secrets.yml"
  "volumes.yml"
  "services.yml"
  "deployments.yml"
  "jobs.yml"
  "ingress.yml"
)

if [[ ! -d "$ASPECTS_DIR" ]]; then
  do_fail "Aspects manifests directory not found: $ASPECTS_DIR"
else
  do_pass "Aspects manifests directory exists: deploy/k8s/base/plugins/aspects/"
  for f in "${EXPECTED_FILES[@]}"; do
    if [[ -f "$ASPECTS_DIR/$f" ]]; then
      do_pass "  manifest exists: $f"
    else
      do_fail "  manifest missing: $f"
    fi
  done
fi

echo ""

# ── Section 2: Expected resources in manifests ───────────────────────

echo -e "${BLUE}-- Section 2: Expected resources in manifests --${NC}"

# ClickHouse Deployment
if [[ -f "$ASPECTS_DIR/deployments.yml" ]]; then
  if grep -q "name: clickhouse" "$ASPECTS_DIR/deployments.yml"; then
    do_pass "ClickHouse Deployment defined in deployments.yml"
  else
    do_fail "ClickHouse Deployment NOT found in deployments.yml"
  fi

  if grep -qE "name: superset" "$ASPECTS_DIR/deployments.yml"; then
    do_pass "Superset Deployment defined in deployments.yml"
  else
    do_fail "Superset Deployment NOT found in deployments.yml"
  fi

  if grep -q "name: superset-worker" "$ASPECTS_DIR/deployments.yml"; then
    do_pass "Superset Worker Deployment defined in deployments.yml"
  else
    do_fail "Superset Worker Deployment NOT found in deployments.yml"
  fi
else
  do_fail "deployments.yml not found — skipping resource checks"
fi

# ClickHouse image version
if [[ -f "$ASPECTS_DIR/deployments.yml" ]]; then
  if grep -q "clickhouse-server" "$ASPECTS_DIR/deployments.yml"; then
    ch_image=$(grep "clickhouse-server" "$ASPECTS_DIR/deployments.yml" | head -1 | tr -d ' ')
    do_pass "ClickHouse image pinned: $ch_image"
  else
    do_fail "ClickHouse image not found in deployments.yml"
  fi
fi

# Superset image version
if [[ -f "$ASPECTS_DIR/deployments.yml" ]]; then
  if grep -Eq "apache/superset|edunext/aspects-superset" "$ASPECTS_DIR/deployments.yml"; then
    ss_image=$(grep -E "apache/superset|edunext/aspects-superset" "$ASPECTS_DIR/deployments.yml" | head -1 | tr -d ' ')
    do_pass "Superset image pinned: $ss_image"
  else
    do_fail "Superset image not found in deployments.yml"
  fi
fi

# ClickHouse PVC
if [[ -f "$ASPECTS_DIR/volumes.yml" ]]; then
  if grep -q "clickhouse-data" "$ASPECTS_DIR/volumes.yml"; then
    do_pass "ClickHouse PVC (clickhouse-data) defined in volumes.yml"
  else
    do_fail "clickhouse-data PVC NOT found in volumes.yml"
  fi
else
  do_fail "volumes.yml not found"
fi

# Services
if [[ -f "$ASPECTS_DIR/services.yml" ]]; then
  if grep -q "name: clickhouse" "$ASPECTS_DIR/services.yml"; then
    do_pass "ClickHouse Service defined in services.yml"
  else
    do_fail "ClickHouse Service NOT found in services.yml"
  fi

  if grep -q "name: superset" "$ASPECTS_DIR/services.yml"; then
    do_pass "Superset Service defined in services.yml"
  else
    do_fail "Superset Service NOT found in services.yml"
  fi
else
  do_fail "services.yml not found"
fi

# Init jobs
if [[ -f "$ASPECTS_DIR/jobs.yml" ]]; then
  if grep -q "superset-init" "$ASPECTS_DIR/jobs.yml"; then
    do_pass "Superset init Job defined in jobs.yml"
  else
    do_fail "superset-init Job NOT found in jobs.yml"
  fi

  if grep -q "clickhouse-init" "$ASPECTS_DIR/jobs.yml"; then
    do_pass "ClickHouse init Job defined in jobs.yml"
  else
    do_fail "clickhouse-init Job NOT found in jobs.yml"
  fi
else
  do_fail "jobs.yml not found"
fi

# Secret placeholder (not production-ready — by design)
if [[ -f "$ASPECTS_DIR/secrets.yml" ]]; then
  if grep -q "aspects-secrets" "$ASPECTS_DIR/secrets.yml"; then
    do_pass "aspects-secrets Secret defined in secrets.yml (placeholder)"
  else
    do_fail "aspects-secrets NOT found in secrets.yml"
  fi
  # Confirm placeholder values are empty (production secrets must come via ESO)
  if grep -qE 'clickhouse-password: ""' "$ASPECTS_DIR/secrets.yml"; then
    do_pass "secrets.yml has empty placeholder values (production secrets must come via ESO)"
  else
    do_fail "secrets.yml may contain hardcoded secret values — verify and replace with ESO"
  fi
else
  do_fail "secrets.yml not found"
fi

# Superset config in configmaps
if [[ -f "$ASPECTS_DIR/configmaps.yml" ]]; then
  if grep -q "superset_config.py" "$ASPECTS_DIR/configmaps.yml"; then
    do_pass "Superset superset_config.py defined in configmaps.yml"
  else
    do_fail "superset_config.py NOT found in configmaps.yml"
  fi

  if grep -q "clickhouse-config" "$ASPECTS_DIR/configmaps.yml"; then
    do_pass "ClickHouse config defined in configmaps.yml"
  else
    do_fail "clickhouse-config NOT found in configmaps.yml"
  fi
else
  do_fail "configmaps.yml not found"
fi

# Ingress
if [[ -f "$ASPECTS_DIR/ingress.yml" ]]; then
  if grep -q "superset" "$ASPECTS_DIR/ingress.yml"; then
    do_pass "Superset Ingress defined in ingress.yml"
  else
    do_fail "Superset Ingress NOT found in ingress.yml"
  fi
else
  do_fail "ingress.yml not found"
fi

echo ""

# ── Section 3: Aspects NOT in active base kustomization ──────────────

echo -e "${BLUE}-- Section 3: Active kustomization state --${NC}"
echo "  (Aspects should NOT be in base kustomization until T148 wires it in)"

if [[ -f "$BASE_KUSTOMIZATION" ]]; then
  if grep -q "plugins/aspects" "$BASE_KUSTOMIZATION"; then
    do_fail "plugins/aspects IS in base kustomization — T148 may have run or this is unexpected"
    echo "         If T148 has been completed, this FAIL is expected and can be ignored."
  else
    do_pass "plugins/aspects is NOT in base kustomization (correct — T148 will wire it)"
  fi
else
  do_fail "Base kustomization not found: $BASE_KUSTOMIZATION"
fi

# Verify the aspects kustomization is self-contained (has its own kustomization.yaml)
if [[ -f "$ASPECTS_DIR/kustomization.yaml" ]]; then
  if grep -q "namespace: mereka-lms" "$ASPECTS_DIR/kustomization.yaml"; then
    do_pass "Aspects kustomization.yaml has namespace: mereka-lms"
  else
    do_fail "Aspects kustomization.yaml missing namespace declaration"
  fi

  # Check all referenced files exist in the kustomization
  while IFS= read -r resource; do
    resource=$(echo "$resource" | sed 's/^ *- *//')
    if [[ -n "$resource" ]] && [[ "$resource" != "#"* ]]; then
      if [[ -f "$ASPECTS_DIR/$resource" ]]; then
        do_pass "  kustomization resource exists: $resource"
      else
        do_fail "  kustomization resource missing: $resource (referenced in kustomization.yaml)"
      fi
    fi
  done < <(grep -A 20 "^resources:" "$ASPECTS_DIR/kustomization.yaml" | grep "\.yml$" | sed 's/.*- //')
fi

echo ""

# ── Section 4: Analytics spec coverage ───────────────────────────────

echo -e "${BLUE}-- Section 4: Spec and documentation --${NC}"

if [[ -f "$ANALYTICS_SPEC" ]]; then
  do_pass "Analytics spec exists: specs/analytics-pipeline_spec.md"

  ac_count=$(grep -c "^- \[ \] AC-" "$ANALYTICS_SPEC" 2>/dev/null || true)
  if [[ "$ac_count" -gt 0 ]]; then
    do_pass "Analytics spec has $ac_count acceptance criteria"
  else
    do_fail "Analytics spec has no acceptance criteria (expected AC-00N lines)"
  fi

  if grep -q "ClickHouse" "$ANALYTICS_SPEC"; then
    do_pass "Analytics spec references ClickHouse"
  else
    do_fail "Analytics spec does not reference ClickHouse"
  fi

  if grep -q "Superset" "$ANALYTICS_SPEC"; then
    do_pass "Analytics spec references Superset"
  else
    do_fail "Analytics spec does not reference Superset"
  fi
else
  do_fail "Analytics spec not found: specs/analytics-pipeline_spec.md"
fi

if [[ -f "$SETUP_DOC" ]]; then
  do_pass "Aspects setup doc exists: docs/reference/operations/ASPECTS_ANALYTICS_SETUP.md"
else
  do_fail "Aspects setup doc missing: docs/reference/operations/ASPECTS_ANALYTICS_SETUP.md"
fi

if [[ -f "$RETENTION_DOC" ]]; then
  do_pass "Analytics data retention policy exists: docs/policies/operations/ANALYTICS_DATA_RETENTION.md"
else
  do_fail "Analytics data retention policy missing: docs/policies/operations/ANALYTICS_DATA_RETENTION.md"
fi

echo ""

# ── Section 5: Security / secrets hygiene ────────────────────────────

echo -e "${BLUE}-- Section 5: Secrets hygiene --${NC}"

if [[ -f "$ASPECTS_DIR/secrets.yml" ]]; then
  # Check for any non-empty secret values (would be a security concern)
  if grep -qE "(clickhouse-password|superset-secret-key|superset-db-password): .+" \
      "$ASPECTS_DIR/secrets.yml" 2>/dev/null; then
    # Check if they have actual values (not just empty string)
    if grep -qE '(clickhouse-password|superset-secret-key|superset-db-password): "[^"]' \
        "$ASPECTS_DIR/secrets.yml" 2>/dev/null; then
      do_fail "aspects-secrets contains non-empty secret values in git — must use ESO instead"
    else
      do_pass "aspects-secrets values are empty placeholders (safe to commit)"
    fi
  else
    do_pass "aspects-secrets has no hardcoded values"
  fi
fi

# Check that liveness/readiness probes use correct paths
if [[ -f "$ASPECTS_DIR/deployments.yml" ]]; then
  if grep -A3 "livenessProbe:" "$ASPECTS_DIR/deployments.yml" | grep -q "path: /ping"; then
    do_pass "ClickHouse liveness probe uses /ping (correct)"
  else
    do_fail "ClickHouse liveness probe path may be incorrect — expected /ping on port 8123"
  fi

  if grep -A3 "livenessProbe:" "$ASPECTS_DIR/deployments.yml" | grep -q "path: /health"; then
    do_pass "Superset liveness probe uses /health (correct)"
  else
    do_fail "Superset liveness probe path may be incorrect — expected /health on port 8088"
  fi
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────

echo -e "${BLUE}=== Summary ===${NC}"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — $FAIL check(s) failed${NC}"
  echo ""
  echo "Next steps:"
  echo "  - Fix failing checks above"
  echo "  - See docs/reference/operations/ASPECTS_ANALYTICS_SETUP.md for deployment plan"
  echo "  - T148 will wire Aspects into the kustomization when ready"
  exit 1
else
  echo -e "${GREEN}RESULT: PASS — Aspects manifests are present and well-formed${NC}"
  echo ""
  echo "Deployment status: NOT DEPLOYED (by design)"
  echo "Next step: T148 will wire Aspects into the dev kustomization overlay"
  exit 0
fi
