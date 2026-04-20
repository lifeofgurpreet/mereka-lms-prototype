#!/usr/bin/env bash
# check-enterprise-mfe-no-workaround.sh
# @spec: platform-middleware-custom-apps_spec.md
# @covers AC-DEP-108
#
# Pre-merge / pre-deploy gate: FAIL if any runtime NREUM-strip workaround logic
# re-enters the enterprise MFE K8s manifests.
#
# This script is intended for CI (GitHub Actions policy-checks) and local pre-commit.
# Exit 0 = clean (no workaround). Exit 1 = workaround detected (block merge).
#
# Usage:
#   bash scripts/qa/check-enterprise-mfe-no-workaround.sh

set -euo pipefail

PASS=0
FAIL=0

pass_check() { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail_check() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

ADMIN_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/admin-portal-deployment.yaml"
LEARNER_DEPLOY="deploy/k8s/base/apps/enterprise/mfe/learner-portal-deployment.yaml"

echo "=== Pre-merge gate: enterprise MFE must not contain runtime NREUM workaround ==="
echo ""

# --- AC-DEP-108: No strip-nreum / sanitize-enterprise / copy-dist initContainers ---
echo "--- AC-DEP-108: No strip-nreum workaround initContainers in manifests ---"

for DEPLOY in "$ADMIN_DEPLOY" "$LEARNER_DEPLOY"; do
  if [ ! -f "$DEPLOY" ]; then
    fail_check "Manifest not found: $DEPLOY"
    continue
  fi

  BASENAME=$(basename "$DEPLOY")

  if grep -qE 'strip-nreum|sanitize-enterprise-index-html|sanitize-enterprise' "$DEPLOY"; then
    fail_check "$BASENAME: contains strip-nreum / sanitize-enterprise initContainer — remove it; NREUM must be stripped at image build time"
  else
    pass_check "$BASENAME: no strip-nreum / sanitize-enterprise initContainer"
  fi

  if grep -qE 'undefined_license_key|undefined_account_id|undefined_application_id' "$DEPLOY"; then
    fail_check "$BASENAME: contains undefined NR key placeholder literals — must not appear in manifests"
  else
    pass_check "$BASENAME: no undefined NR key placeholders"
  fi

  # Warn if Python image is used (sign of old runtime strip approach)
  if grep -q 'docker.io/library/python\|python:latest\|python:3' "$DEPLOY"; then
    fail_check "$BASENAME: uses Python Docker image in initContainers — runtime strip detected; use build-time clean image instead"
  else
    pass_check "$BASENAME: no Python runtime strip image"
  fi
done

echo ""

# --- AC-DEP-108: Verify build-time clean Dockerfiles exist ---
echo "--- AC-DEP-108: Build-time clean Dockerfiles present ---"

DOCKERFILE_ADMIN="infrastructure/docker/enterprise-mfe-clean/Dockerfile.admin-portal"
DOCKERFILE_LEARNER="infrastructure/docker/enterprise-mfe-clean/Dockerfile.learner-portal"
BUILD_SCRIPT="scripts/infra/build-enterprise-mfe-clean.sh"

for F in "$DOCKERFILE_ADMIN" "$DOCKERFILE_LEARNER" "$BUILD_SCRIPT"; do
  if [ -f "$F" ]; then
    pass_check "Build-time artifact exists: $F"
  else
    fail_check "Missing build-time artifact: $F — run build-enterprise-mfe-clean.sh to create"
  fi
done

# --- AC-DEP-108: Production kustomization pins enterprise MFE to clean tag ---
echo ""
echo "--- AC-DEP-108: Production kustomization pins enterprise MFE images ---"

KUSTOMIZATION="deploy/k8s/overlays/production/kustomization.yaml"
if [ ! -f "$KUSTOMIZATION" ]; then
  # Wave 9 (#1900) deleted deploy/k8s/overlays/production/ as a deprecated shadow
  # overlay. Authoritative production overlay with enterprise MFE image pins
  # lives in bbi-infrastructure/apps/mereka-lms/overlays/prod/. Treat absence as
  # not-applicable for this repo.
  pass_check "Production kustomization absent (Wave 9 shadow deletion — see bbi-infrastructure)"
else
  if grep -q 'enterprise-admin-portal' "$KUSTOMIZATION"; then
    pass_check "enterprise-admin-portal image pinned in production kustomization"
  else
    fail_check "enterprise-admin-portal NOT pinned in production kustomization — add image override with nreum-clean tag"
  fi

  if grep -q 'enterprise-learner-portal' "$KUSTOMIZATION"; then
    pass_check "enterprise-learner-portal image pinned in production kustomization"
  else
    fail_check "enterprise-learner-portal NOT pinned in production kustomization — add image override with nreum-clean tag"
  fi

  if grep -q 'nreum-clean' "$KUSTOMIZATION"; then
    pass_check "Production kustomization references nreum-clean tag"
  else
    fail_check "Production kustomization does NOT reference nreum-clean tag — run build-enterprise-mfe-clean.sh and update tag"
  fi
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS | FAIL: $FAIL"
echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "  RESULT: FAIL — runtime NREUM workaround detected or build artifacts missing"
  echo "  Fix: bash scripts/infra/build-enterprise-mfe-clean.sh"
  echo "  Docs: docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md (Section 9)"
  exit 1
else
  echo "  RESULT: PASS — enterprise MFE manifests are clean (no runtime workaround)"
  exit 0
fi
