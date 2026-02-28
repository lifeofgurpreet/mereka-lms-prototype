#!/usr/bin/env bash
# @spec: analytics-pipeline_spec.md
# @covers AC-ASPRD-001, AC-ASPRD-002, AC-ASPRD-003
#
# Aspects Deployment Readiness Verification
#
# Validates that:
# - Deployment readiness contract exists and is complete
# - ADR-017 exists and documents deferral
# - K8s manifests exist but are NOT deployed
# - Infrastructure is ready for deployment when decision gate approves
#
# Usage:
#   ./scripts/qa/verify-aspects-deployment-readiness.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# --- Paths ---
CONTRACT="docs/architecture/ASPECTS_DEPLOYMENT_READINESS.md"
ADR="docs/adr/017-analytics-target-decision.md"
ASPECTS_K8S_DIR="deploy/k8s/base/plugins/aspects"
PROD_KUSTOMIZATION="deploy/k8s/overlays/production/kustomization.yaml"
TUTOR_CONFIG="infrastructure/tutor/config.example.yml"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

do_pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
do_fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
do_warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; WARNED=$((WARNED + 1)); }

echo "══════════════════════════════════════════════════════════════"
echo "  Aspects Deployment Readiness Verification"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# AC-ASPRD-001: Contract documents complete Aspects deployment prerequisites and steps
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  Contract Completeness (AC-ASPRD-001)"
echo "──────────────────────────────────────────────────────────────"

# Check contract exists
if [[ -f "$CONTRACT" ]]; then
  do_pass "[AC-ASPRD-001] Deployment readiness contract exists at $CONTRACT"
else
  do_fail "[AC-ASPRD-001] Contract missing: $CONTRACT"
fi

# Check contract has prerequisites section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Prerequisites Checklist" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract has Prerequisites Checklist section"
  else
    do_fail "[AC-ASPRD-001] Contract missing Prerequisites Checklist section"
  fi
fi

# Check contract has decision gate section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "Decision Gate" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents decision gate approval"
  else
    do_fail "[AC-ASPRD-001] Contract missing decision gate section"
  fi
fi

# Check contract has infrastructure readiness section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "Infrastructure Readiness" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents infrastructure readiness"
  else
    do_fail "[AC-ASPRD-001] Contract missing infrastructure readiness section"
  fi
fi

# Check contract has secrets management section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "Secrets Management" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents secrets management"
  else
    do_fail "[AC-ASPRD-001] Contract missing secrets management section"
  fi
fi

# Check contract has deployment steps section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Deployment Steps" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract has Deployment Steps section"
  else
    do_fail "[AC-ASPRD-001] Contract missing Deployment Steps section"
  fi
fi

# Check contract has rollback procedure
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Rollback Procedure" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract has Rollback Procedure section"
  else
    do_fail "[AC-ASPRD-001] Contract missing Rollback Procedure section"
  fi
fi

# Check contract has monitoring requirements
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Monitoring Requirements" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract has Monitoring Requirements section"
  else
    do_fail "[AC-ASPRD-001] Contract missing Monitoring Requirements section"
  fi
fi

# Check contract has cost estimate
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Cost Estimate" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract has Cost Estimate section"
  else
    do_fail "[AC-ASPRD-001] Contract missing Cost Estimate section"
  fi
fi

# Check contract documents manifest inventory
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Kubernetes Manifest Inventory" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents K8s manifest inventory"
  else
    do_fail "[AC-ASPRD-001] Contract missing manifest inventory section"
  fi
fi

# Check contract documents image build requirements
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Image Build Requirements" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents image build requirements"
  else
    do_fail "[AC-ASPRD-001] Contract missing image build requirements"
  fi
fi

# Check contract mentions ClickHouse
if [[ -f "$CONTRACT" ]]; then
  if grep -qi "ClickHouse" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents ClickHouse requirements"
  else
    do_fail "[AC-ASPRD-001] Contract missing ClickHouse documentation"
  fi
fi

# Check contract mentions Superset
if [[ -f "$CONTRACT" ]]; then
  if grep -qi "Superset" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents Superset requirements"
  else
    do_fail "[AC-ASPRD-001] Contract missing Superset documentation"
  fi
fi

# Check contract mentions Ralph
if [[ -f "$CONTRACT" ]]; then
  if grep -qi "Ralph" "$CONTRACT"; then
    do_pass "[AC-ASPRD-001] Contract documents Ralph event pipeline"
  else
    do_fail "[AC-ASPRD-001] Contract missing Ralph documentation"
  fi
fi

echo ""

# ============================================================================
# AC-ASPRD-002: Verifier confirms infrastructure readiness state (manifests exist, not deployed)
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  Infrastructure Readiness State (AC-ASPRD-002)"
echo "──────────────────────────────────────────────────────────────"

# Check ADR-017 exists
if [[ -f "$ADR" ]]; then
  do_pass "[AC-ASPRD-002] ADR-017 exists at $ADR"
else
  do_fail "[AC-ASPRD-002] ADR-017 missing: $ADR"
fi

# Check ADR-017 status is Deferred or Accepted
if [[ -f "$ADR" ]]; then
  ADR_STATUS=$(grep "^**Status" "$ADR" | head -1 || echo "")
  if echo "$ADR_STATUS" | grep -qi "Deferred\|Accepted"; then
    do_pass "[AC-ASPRD-002] ADR-017 status is valid: $ADR_STATUS"
  else
    do_warn "[AC-ASPRD-002] ADR-017 status unexpected: $ADR_STATUS"
  fi
fi

# Check Aspects K8s manifests directory exists
if [[ -d "$ASPECTS_K8S_DIR" ]]; then
  do_pass "[AC-ASPRD-002] Aspects K8s manifests directory exists: $ASPECTS_K8S_DIR"
else
  do_fail "[AC-ASPRD-002] Aspects K8s manifests directory missing: $ASPECTS_K8S_DIR"
fi

# Check Aspects K8s manifests exist
EXPECTED_MANIFESTS=(
  "kustomization.yaml"
  "configmaps.yml"
  "secrets.yml"
  "volumes.yml"
  "deployments.yml"
  "services.yml"
  "jobs.yml"
  "sync-job.yml"
  "ingress.yml"
)

MANIFEST_COUNT=0
for manifest in "${EXPECTED_MANIFESTS[@]}"; do
  if [[ -f "$ASPECTS_K8S_DIR/$manifest" ]]; then
    MANIFEST_COUNT=$((MANIFEST_COUNT + 1))
  fi
done

if [[ $MANIFEST_COUNT -eq ${#EXPECTED_MANIFESTS[@]} ]]; then
  do_pass "[AC-ASPRD-002] All 9 Aspects K8s manifests exist"
else
  do_fail "[AC-ASPRD-002] Only $MANIFEST_COUNT/${#EXPECTED_MANIFESTS[@]} Aspects manifests found"
fi

# Check production kustomization aspects state matches ADR status
if [[ -f "$PROD_KUSTOMIZATION" ]]; then
  ADR_IS_ACCEPTED=0
  if [[ -f "$ADR" ]]; then
    adr_check=$(grep "^**Status" "$ADR" | head -1 || echo "")
    if echo "$adr_check" | grep -qi "Accepted"; then
      ADR_IS_ACCEPTED=1
    fi
  fi
  if grep -q "aspects" "$PROD_KUSTOMIZATION"; then
    if [[ "$ADR_IS_ACCEPTED" -eq 1 ]]; then
      do_pass "[AC-ASPRD-002] Production kustomization references aspects (correct — ADR-017 Accepted)"
    else
      do_fail "[AC-ASPRD-002] Production kustomization references aspects (should NOT be deployed while ADR-017 is Deferred)"
    fi
  else
    if [[ "$ADR_IS_ACCEPTED" -eq 1 ]]; then
      do_fail "[AC-ASPRD-002] Production kustomization does NOT reference aspects (ADR-017 is Accepted — should be wired)"
    else
      do_pass "[AC-ASPRD-002] Production kustomization does NOT reference aspects (correct for Deferred)"
    fi
  fi
else
  do_fail "[AC-ASPRD-002] Production kustomization missing: $PROD_KUSTOMIZATION"
fi

# Check Tutor config has aspects plugin reference (available but not enabled)
if [[ -f "$TUTOR_CONFIG" ]]; then
  if grep -q "aspects" "$TUTOR_CONFIG"; then
    do_pass "[AC-ASPRD-002] Tutor config.example.yml references aspects plugin"
  else
    do_fail "[AC-ASPRD-002] Tutor config.example.yml missing aspects plugin reference"
  fi
else
  do_fail "[AC-ASPRD-002] Tutor config.example.yml missing: $TUTOR_CONFIG"
fi

# Check deployments.yml for ClickHouse deployment
if [[ -f "$ASPECTS_K8S_DIR/deployments.yml" ]]; then
  if grep -qi "clickhouse" "$ASPECTS_K8S_DIR/deployments.yml"; then
    do_pass "[AC-ASPRD-002] deployments.yml includes ClickHouse"
  else
    do_fail "[AC-ASPRD-002] deployments.yml missing ClickHouse deployment"
  fi
fi

# Check deployments.yml for Superset deployment
if [[ -f "$ASPECTS_K8S_DIR/deployments.yml" ]]; then
  if grep -qi "superset" "$ASPECTS_K8S_DIR/deployments.yml"; then
    do_pass "[AC-ASPRD-002] deployments.yml includes Superset"
  else
    do_fail "[AC-ASPRD-002] deployments.yml missing Superset deployment"
  fi
fi

# Check services.yml for Aspects services
if [[ -f "$ASPECTS_K8S_DIR/services.yml" ]]; then
  if grep -qi "kind: Service" "$ASPECTS_K8S_DIR/services.yml"; then
    do_pass "[AC-ASPRD-002] services.yml includes Service definitions"
  else
    do_fail "[AC-ASPRD-002] services.yml missing Service definitions"
  fi
fi

# Check volumes.yml for PVC definitions
if [[ -f "$ASPECTS_K8S_DIR/volumes.yml" ]]; then
  if grep -qi "PersistentVolumeClaim" "$ASPECTS_K8S_DIR/volumes.yml"; then
    do_pass "[AC-ASPRD-002] volumes.yml includes PersistentVolumeClaim"
  else
    do_fail "[AC-ASPRD-002] volumes.yml missing PersistentVolumeClaim"
  fi
fi

echo ""

# ============================================================================
# AC-ASPRD-003: CI gate tracks deployment readiness status
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  CI Gate Integration (AC-ASPRD-003)"
echo "──────────────────────────────────────────────────────────────"

# Check this verifier script exists
if [[ -f "scripts/qa/verify-aspects-deployment-readiness.sh" ]]; then
  do_pass "[AC-ASPRD-003] Deployment readiness verifier exists"
else
  do_fail "[AC-ASPRD-003] Deployment readiness verifier missing"
fi

# Check script is executable
if [[ -x "scripts/qa/verify-aspects-deployment-readiness.sh" ]]; then
  do_pass "[AC-ASPRD-003] Verifier is executable"
else
  do_fail "[AC-ASPRD-003] Verifier is not executable (run: chmod +x scripts/qa/verify-aspects-deployment-readiness.sh)"
fi

# Check script has @covers annotations
ANNOTATION_COUNT=$(grep -c "@covers" "scripts/qa/verify-aspects-deployment-readiness.sh" || echo 0)
if [[ $ANNOTATION_COUNT -gt 0 ]]; then
  do_pass "[AC-ASPRD-003] Verifier has @covers annotations"
else
  do_fail "[AC-ASPRD-003] Verifier missing @covers annotations"
fi

# Check script has @spec annotation
SPEC_ANNOTATION_COUNT=$(grep -c "@spec:" "scripts/qa/verify-aspects-deployment-readiness.sh" || echo 0)
if [[ $SPEC_ANNOTATION_COUNT -gt 0 ]]; then
  do_pass "[AC-ASPRD-003] Verifier has @spec annotation"
else
  do_fail "[AC-ASPRD-003] Verifier missing @spec annotation"
fi

# Check contract references ADR-017
if [[ -f "$CONTRACT" ]]; then
  if grep -q "ADR-017" "$CONTRACT"; then
    do_pass "[AC-ASPRD-003] Contract references ADR-017"
  else
    do_fail "[AC-ASPRD-003] Contract missing ADR-017 reference"
  fi
fi

# Check contract has related documentation section
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Related Documentation" "$CONTRACT"; then
    do_pass "[AC-ASPRD-003] Contract has Related Documentation section"
  else
    do_fail "[AC-ASPRD-003] Contract missing Related Documentation section"
  fi
fi

# Check contract links to analytics spec
if [[ -f "$CONTRACT" ]]; then
  if grep -q "analytics-pipeline_spec.md" "$CONTRACT"; then
    do_pass "[AC-ASPRD-003] Contract links to analytics-pipeline spec"
  else
    do_fail "[AC-ASPRD-003] Contract missing analytics-pipeline spec link"
  fi
fi

# Check contract has success criteria
if [[ -f "$CONTRACT" ]]; then
  if grep -q "## Success Criteria" "$CONTRACT"; then
    do_pass "[AC-ASPRD-003] Contract defines success criteria"
  else
    do_fail "[AC-ASPRD-003] Contract missing success criteria section"
  fi
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Summary"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  ${GREEN}PASS${NC}:  $PASSED"
echo "  ${RED}FAIL${NC}:  $FAILED"
echo "  ${YELLOW}WARN${NC}:  $WARNED"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo "✓ Aspects deployment readiness contract is complete"
  echo "✓ Infrastructure manifests exist but are NOT deployed (correct state)"
  echo "✓ Ready for deployment when ADR-017 decision gate approves"
  exit 0
else
  echo "✗ Deployment readiness verification failed"
  echo "  Review failed checks above and address issues"
  exit 1
fi
