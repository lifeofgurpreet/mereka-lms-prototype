#!/usr/bin/env bash
# @spec: ci-cd-pipeline_spec.md
# @covers AC-001, AC-005, AC-006, AC-009, AC-010, AC-011, AC-013, AC-014, AC-019, AC-020, AC-027, AC-028
#
# Comprehensive CI/CD pipeline verification script.
# Validates the build pipeline, registry configuration, GitOps deployment,
# release automation, and security scanning contracts.
#
# Usage:
#   ./scripts/qa/verify-ci-cd-pipeline.sh
#   ./scripts/qa/verify-ci-cd-pipeline.sh --section build
#   ./scripts/qa/verify-ci-cd-pipeline.sh --section registry
#   ./scripts/qa/verify-ci-cd-pipeline.sh --section gitops
#   ./scripts/qa/verify-ci-cd-pipeline.sh --section security
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# --- Paths ---
BUILD_WF=".github/workflows/build-tutor-images.yml"
CI_WF=".github/workflows/ci.yml"
EVIDENCE_WF=".github/workflows/release-evidence.yml"
FRONTEND_RUNTIME_QA_WF=".github/workflows/frontend-runtime-qa.yml"
FRONTEND_BEFORE_AFTER_VISUALS_WF=".github/workflows/frontend-before-after-visuals.yml"
RUNTIME_THEME_DRIFT_DIAGNOSE_WF=".github/workflows/runtime-theme-drift-diagnose.yml"
PHASE2_SMOKE_EVIDENCE_WF=".github/workflows/phase2-smoke-evidence.yml"
RELEASE_SCRIPT="scripts/infra/release-openedx-gitops.sh"
DIGEST_HELPER="scripts/infra/resolve-image-digest.sh"
WORKFLOWS_DIR=".github/workflows"
CI_STATIC_LIST=".github/ci-scripts-static.txt"

# --- Colours ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0
SECTION_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --section) SECTION_FILTER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--section build|registry|gitops|security]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "  ${YELLOW}SKIP${NC}  $1"; SKIPPED=$((SKIPPED + 1)); }

# ============================================================================
# SECTION: Build Pipeline
# ============================================================================
check_build_pipeline() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Build Pipeline"
  echo "══════════════════════════════════════════════════════════════"

  # AC-009: Build workflow exists and is valid YAML
  if [[ ! -f "$BUILD_WF" ]]; then
    fail "[AC-009] Build workflow missing: $BUILD_WF"
    return
  fi
  if python3 -c "import yaml; yaml.safe_load(open('$BUILD_WF'))" 2>/dev/null; then
    pass "[AC-009] Build workflow exists and is valid YAML"
  else
    fail "[AC-009] Build workflow is not valid YAML"
  fi

  # AC-009: OpenEdX build job exists with proper triggers
  if grep -q '^  build-openedx:' "$BUILD_WF"; then
    pass "[AC-009] OpenEdX build job defined in build workflow"
  else
    fail "[AC-009] OpenEdX build job missing from build workflow"
  fi

  # AC-009: Build triggers on push to main with path filter
  if grep -q 'infrastructure/tutor/\*\*' "$BUILD_WF" && grep -q 'push:' "$BUILD_WF"; then
    pass "[AC-009] Build triggers on push to main with tutor path filter"
  else
    fail "[AC-009] Build workflow missing push trigger with path filter"
  fi

  # AC-009: Build supports workflow_dispatch
  if grep -q 'workflow_dispatch:' "$BUILD_WF"; then
    pass "[AC-009] Build workflow supports manual dispatch"
  else
    fail "[AC-009] Build workflow missing workflow_dispatch trigger"
  fi

  # AC-011: MFE build job exists with proper triggers
  if grep -q '^  build-mfe:' "$BUILD_WF"; then
    pass "[AC-011] MFE build job defined in build workflow"
  else
    fail "[AC-011] MFE build job missing from build workflow"
  fi

  # AC-009: Docker BuildKit enabled
  if grep -q 'DOCKER_BUILDKIT: 1' "$BUILD_WF"; then
    pass "[AC-009] Docker BuildKit enabled (DOCKER_BUILDKIT=1)"
  else
    fail "[AC-009] Docker BuildKit not enabled in build workflow"
  fi

  # AC-009: Build depends on lint job
  if grep -q 'needs: lint' "$BUILD_WF" || grep -q 'needs:.*lint' "$BUILD_WF"; then
    pass "[AC-009] Build jobs depend on lint passing"
  else
    fail "[AC-009] Build jobs do not depend on lint job"
  fi

  # AC-013: Image tags use immutable refs (git SHA), NOT :latest
  if grep -q 'inputs.image_tag || github.sha' "$BUILD_WF"; then
    pass "[AC-013] Image tags default to git SHA (immutable)"
  else
    fail "[AC-013] Image tags do not default to git SHA"
  fi

  # AC-013: No :latest tags pushed to Artifact Registry
  if grep -E 'docker push.*:latest([[:space:]]|$)' "$BUILD_WF" >/dev/null 2>&1; then
    fail "[AC-013] Build workflow publishes mutable :latest tags to registry"
  else
    pass "[AC-013] No :latest tags pushed to Artifact Registry"
  fi

  # AC-011: Branding verification step exists in OpenEdX build
  if grep -q 'Verify OpenEdX image branding contract' "$BUILD_WF"; then
    pass "[AC-011] OpenEdX branding verification step exists in build"
  else
    fail "[AC-011] OpenEdX branding verification step missing from build"
  fi

  # AC-011: Branding verification step exists in MFE build
  if grep -q 'Verify MFE image branding contract' "$BUILD_WF"; then
    pass "[AC-011] MFE branding verification step exists in build"
  else
    fail "[AC-011] MFE branding verification step missing from build"
  fi

  # AC-011: Branding verification log uploaded as artifact
  if grep -q 'openedx-branding-contract-log' "$BUILD_WF" && grep -q 'mfe-branding-contract-log' "$BUILD_WF"; then
    pass "[AC-011] Branding verification logs uploaded as artifacts"
  else
    fail "[AC-011] Branding verification log artifacts missing"
  fi

  # AC-009: Tutor version pinned in build dependency file (loaded by setup-python-env action)
  # Updated to Tutor 21.0.0 (Ulmo) from 18.2.2 (Redwood) — 2026-03-06
  if [[ -f "requirements-tutor.txt" ]] \
    && grep -q 'tutor\[full\]==21.0.0' requirements-tutor.txt \
    && grep -q 'tutor-mfe==21.0.0' requirements-tutor.txt \
    && grep -q "requirements-file: 'requirements-tutor.txt'" "$BUILD_WF"; then
    pass "[AC-009] Tutor version pinned via requirements-tutor.txt and wired into build workflow"
  else
    fail "[AC-009] Tutor version pinning contract missing (requirements-tutor.txt + workflow wiring)"
  fi

  # AC-009: apply-patches.sh called after config save
  local patch_count
  patch_count=$(grep -c 'apply-patches.sh' "$BUILD_WF" 2>/dev/null || echo "0")
  if [[ "$patch_count" -ge 2 ]]; then
    pass "[AC-009] apply-patches.sh called in both openedx and mfe build jobs"
  else
    fail "[AC-009] apply-patches.sh not called in both build jobs (found $patch_count)"
  fi

  # AC-011: MFE build sets NODE_OPTIONS for memory
  if grep -q 'max-old-space-size=6144' "$BUILD_WF"; then
    pass "[AC-011] MFE build sets NODE_OPTIONS memory limit (6144MB)"
  else
    fail "[AC-011] MFE build missing NODE_OPTIONS memory limit"
  fi
}

# ============================================================================
# SECTION: Registry & Images
# ============================================================================
check_registry() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Registry & Images"
  echo "══════════════════════════════════════════════════════════════"

  if [[ ! -f "$BUILD_WF" ]]; then
    fail "[AC-009] Cannot check registry — build workflow missing"
    return
  fi

  # AC-009: Image push targets correct registry (GHCR — migrated from GCP Artifact Registry)
  if grep -q 'ghcr.io/biji-biji-initiative/mereka-lms' "$BUILD_WF"; then
    pass "[AC-009] Images push to correct registry (ghcr.io/biji-biji-initiative/mereka-lms)"
  else
    fail "[AC-009] Images do not target correct registry (expected ghcr.io/biji-biji-initiative/mereka-lms)"
  fi

  # AC-009: Both openedx and mfe images are pushed
  local openedx_push mfe_push
  openedx_push=$(grep -c 'docker push.*openedx:' "$BUILD_WF" 2>/dev/null || echo "0")
  mfe_push=$(grep -c 'docker push.*mfe:' "$BUILD_WF" 2>/dev/null || echo "0")
  if [[ "$openedx_push" -ge 1 && "$mfe_push" -ge 1 ]]; then
    pass "[AC-009] Both openedx and mfe images are pushed to registry"
  else
    fail "[AC-009] Missing image pushes (openedx=$openedx_push, mfe=$mfe_push)"
  fi

  # AC-009: Images tagged with short SHA too
  if grep -q 'SHORT_SHA="${GITHUB_SHA::8}"' "$BUILD_WF"; then
    pass "[AC-009] Images tagged with 8-char short SHA"
  else
    fail "[AC-009] Short SHA tagging missing"
  fi

  # AC-010: Digest resolution step exists for openedx
  if grep -q 'Resolve pushed openedx digest' "$BUILD_WF"; then
    pass "[AC-010] Digest resolution step exists for openedx"
  else
    fail "[AC-010] Digest resolution step missing for openedx"
  fi

  # AC-010: Digest resolution step exists for mfe
  if grep -q 'Resolve pushed mfe digest' "$BUILD_WF"; then
    pass "[AC-010] Digest resolution step exists for mfe"
  else
    fail "[AC-010] Digest resolution step missing for mfe"
  fi

  # AC-010: Shared digest helper script used
  if [[ -f "$DIGEST_HELPER" && -x "$DIGEST_HELPER" ]]; then
    pass "[AC-010] Shared digest helper script exists and is executable"
  elif [[ -f "$DIGEST_HELPER" ]]; then
    fail "[AC-010] Digest helper exists but is not executable"
  else
    fail "[AC-010] Shared digest helper script missing: $DIGEST_HELPER"
  fi

  # AC-010: Digest exposed as job output
  if grep -q 'image_digest:.*steps.digest.outputs.digest' "$BUILD_WF"; then
    pass "[AC-010] Image digest exposed as job output"
  else
    fail "[AC-010] Image digest not exposed as job output"
  fi

  # AC-009: Registry authentication configured
  # After GHCR migration: uses GITHUB_TOKEN (docker login ghcr.io) instead of GCP auth.
  # GCP auth (gcp-gke-auth) is only needed for GKE deployments, not image pushes to GHCR.
  if grep -qE 'google-github-actions/auth@(v2|[0-9a-f]{40})(\s*#\s*v2)?' "$BUILD_WF" \
    || grep -q '\./\.github/actions/gcp-gke-auth' "$BUILD_WF"; then
    pass "[AC-009] GCP authentication configured (direct action or gcp-gke-auth composite)"
  elif grep -q 'docker login ghcr.io' "$BUILD_WF" \
    && grep -q 'GITHUB_TOKEN' "$BUILD_WF"; then
    pass "[AC-009] GHCR authentication configured via GITHUB_TOKEN (post-GHCR migration)"
  else
    fail "[AC-009] Registry authentication missing from build workflow"
  fi
}

# ============================================================================
# SECTION: GitOps & Release
# ============================================================================
check_gitops() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  GitOps & Release"
  echo "══════════════════════════════════════════════════════════════"

  if [[ ! -f "$BUILD_WF" ]]; then
    fail "[AC-014] Cannot check GitOps — build workflow missing"
    return
  fi

  # AC-014: GitOps update job exists in build workflow
  if grep -q '^  update-gitops:' "$BUILD_WF"; then
    pass "[AC-014] GitOps update job exists in build workflow"
  else
    fail "[AC-014] GitOps update job missing from build workflow"
  fi

  # AC-014: release-openedx-gitops.sh exists and is executable
  if [[ -f "$RELEASE_SCRIPT" && -x "$RELEASE_SCRIPT" ]]; then
    pass "[AC-014] release-openedx-gitops.sh exists and is executable"
  elif [[ -f "$RELEASE_SCRIPT" ]]; then
    fail "[AC-014] release-openedx-gitops.sh exists but is not executable"
  else
    fail "[AC-014] release-openedx-gitops.sh missing: $RELEASE_SCRIPT"
  fi

  # AC-014: GitOps invokes release script with correct flags
  if grep -q -- '--apply --commit --push' "$BUILD_WF"; then
    pass "[AC-014] GitOps invokes release script with --apply --commit --push"
  else
    fail "[AC-014] GitOps missing --apply --commit --push flags"
  fi

  if grep -q -- '--verify-runtime --wait-seconds 900' "$BUILD_WF"; then
    pass "[AC-014] Production GitOps path wires --verify-runtime with explicit wait budget"
  else
    fail "[AC-014] Missing production runtime verification wiring (--verify-runtime --wait-seconds 900)"
  fi

  # AC-014: Digest pinning supported (--require-digests)
  if grep -q -- '--require-digests' "$BUILD_WF"; then
    pass "[AC-014] Digest pinning supported (--require-digests flag)"
  else
    fail "[AC-014] --require-digests flag missing from GitOps invocation"
  fi

  # AC-014: Both digest flags passed
  if grep -q -- '--openedx-digest' "$BUILD_WF" && grep -q -- '--mfe-digest' "$BUILD_WF"; then
    pass "[AC-014] Both --openedx-digest and --mfe-digest passed to release script"
  else
    fail "[AC-014] Missing digest flags in GitOps invocation"
  fi

  # AC-014: GITOPS_PAT validation
  if grep -q 'GITOPS_PAT' "$BUILD_WF"; then
    pass "[AC-014] GITOPS_PAT secret referenced in GitOps update"
  else
    fail "[AC-014] GITOPS_PAT secret not referenced"
  fi

  # AC-014: Git identity configured for bot commits
  if grep -q 'github-actions\[bot\]' "$BUILD_WF"; then
    pass "[AC-014] Git identity configured as github-actions[bot]"
  else
    fail "[AC-014] Git identity not configured for GitOps commits"
  fi

  # AC-019: Release evidence workflow exists
  if [[ -f "$EVIDENCE_WF" ]]; then
    pass "[AC-019] Release evidence workflow exists"
  else
    fail "[AC-019] Release evidence workflow missing: $EVIDENCE_WF"
  fi

  # AC-019: Release evidence is workflow_dispatch only
  if [[ -f "$EVIDENCE_WF" ]] && grep -q 'workflow_dispatch:' "$EVIDENCE_WF"; then
    pass "[AC-019] Release evidence triggered via workflow_dispatch"
  else
    fail "[AC-019] Release evidence missing workflow_dispatch trigger"
  fi

  # AC-019: Release metadata JSON generated
  if [[ -f "$EVIDENCE_WF" ]] && grep -q 'release-metadata.json' "$EVIDENCE_WF"; then
    pass "[AC-019] Release evidence generates release-metadata.json"
  else
    fail "[AC-019] Release evidence missing release-metadata.json generation"
  fi

  # AC-019: Release evidence uploads artifact bundle
  if [[ -f "$EVIDENCE_WF" ]] && grep -q 'release-evidence-' "$EVIDENCE_WF"; then
    pass "[AC-019] Release evidence uploads artifact bundle"
  else
    fail "[AC-019] Release evidence missing artifact upload"
  fi

  # AC-020: Frontend contract/extended-surface gates are consolidated into ci.yml lanes
  if [[ -f "$CI_WF" && -f "$CI_STATIC_LIST" ]] \
    && grep -qE 'run-scripts-parallel\.sh .github/ci-scripts-static\.txt|run-release-verification-gates\.sh' "$CI_WF" \
    && grep -q '^scripts/qa/verify-paragon-token-coverage\.sh$' "$CI_STATIC_LIST" \
    && grep -q 'verify-certificate-branding\.sh' "$CI_WF" \
    ; then
    pass "[AC-020] Frontend contract and extended-surface checks are consolidated into ci.yml static-validation lanes"
  else
    fail "[AC-020] ci.yml missing consolidated frontend contract/extended-surface gate wiring"
  fi

  # AC-020: Phase2 smoke evidence workflow exists
  if [[ -f "$PHASE2_SMOKE_EVIDENCE_WF" ]]; then
    pass "[AC-020] Phase2 smoke evidence workflow exists"
  else
    fail "[AC-020] Phase2 smoke evidence workflow missing: $PHASE2_SMOKE_EVIDENCE_WF"
  fi

  # AC-020: Phase2 smoke evidence workflow is workflow_dispatch
  if [[ -f "$PHASE2_SMOKE_EVIDENCE_WF" ]] && grep -q 'workflow_dispatch:' "$PHASE2_SMOKE_EVIDENCE_WF"; then
    pass "[AC-020] Phase2 smoke evidence workflow triggered via workflow_dispatch"
  else
    fail "[AC-020] Phase2 smoke evidence workflow missing workflow_dispatch trigger"
  fi

  # AC-020: Phase2 smoke evidence workflow runs smoke verification gate
  if [[ -f "$PHASE2_SMOKE_EVIDENCE_WF" ]] && grep -q 'verify-npm-start-mfe-smoke.sh' "$PHASE2_SMOKE_EVIDENCE_WF"; then
    pass "[AC-020] Phase2 smoke evidence workflow runs npm-start smoke gate"
  else
    fail "[AC-020] Phase2 smoke evidence workflow missing npm-start smoke gate invocation"
  fi

  # AC-020: Frontend runtime QA workflow exists
  if [[ -f "$FRONTEND_RUNTIME_QA_WF" ]]; then
    pass "[AC-020] Frontend runtime QA workflow exists"
  else
    fail "[AC-020] Frontend runtime QA workflow missing: $FRONTEND_RUNTIME_QA_WF"
  fi

  # AC-020: Frontend runtime QA workflow is workflow_dispatch
  if [[ -f "$FRONTEND_RUNTIME_QA_WF" ]] && grep -q 'workflow_dispatch:' "$FRONTEND_RUNTIME_QA_WF"; then
    pass "[AC-020] Frontend runtime QA workflow triggered via workflow_dispatch"
  else
    fail "[AC-020] Frontend runtime QA workflow missing workflow_dispatch trigger"
  fi

  # AC-020: Frontend runtime QA workflow runs both prod/dev runtime make lanes
  if [[ -f "$FRONTEND_RUNTIME_QA_WF" ]] \
    && grep -q 'make qa-frontend-runtime-qa-prod' "$FRONTEND_RUNTIME_QA_WF" \
    && grep -q 'make qa-frontend-runtime-qa-dev' "$FRONTEND_RUNTIME_QA_WF"; then
    pass "[AC-020] Frontend runtime QA workflow runs qa-frontend-runtime-qa-{prod,dev} lanes"
  else
    fail "[AC-020] Frontend runtime QA workflow missing runtime make-lane invocations"
  fi

  # AC-020: Frontend before/after visuals workflow exists
  if [[ -f "$FRONTEND_BEFORE_AFTER_VISUALS_WF" ]]; then
    pass "[AC-020] Frontend before/after visuals workflow exists"
  else
    fail "[AC-020] Frontend before/after visuals workflow missing: $FRONTEND_BEFORE_AFTER_VISUALS_WF"
  fi

  # AC-020: Frontend before/after visuals workflow is workflow_dispatch
  if [[ -f "$FRONTEND_BEFORE_AFTER_VISUALS_WF" ]] && grep -q 'workflow_dispatch:' "$FRONTEND_BEFORE_AFTER_VISUALS_WF"; then
    pass "[AC-020] Frontend before/after visuals workflow triggered via workflow_dispatch"
  else
    fail "[AC-020] Frontend before/after visuals workflow missing workflow_dispatch trigger"
  fi

  # AC-020: Frontend before/after visuals workflow runs before/after report generator
  if [[ -f "$FRONTEND_BEFORE_AFTER_VISUALS_WF" ]] \
    && grep -q 'build-branding-before-after-report.sh' "$FRONTEND_BEFORE_AFTER_VISUALS_WF"; then
    pass "[AC-020] Frontend before/after visuals workflow runs before/after report generation"
  else
    fail "[AC-020] Frontend before/after visuals workflow missing report generation invocation"
  fi

  # AC-020: Runtime theme drift diagnose workflow exists
  if [[ -f "$RUNTIME_THEME_DRIFT_DIAGNOSE_WF" ]]; then
    pass "[AC-020] Runtime theme drift diagnose workflow exists"
  else
    fail "[AC-020] Runtime theme drift diagnose workflow missing: $RUNTIME_THEME_DRIFT_DIAGNOSE_WF"
  fi

  # AC-020: Runtime theme drift diagnose workflow is workflow_dispatch
  if [[ -f "$RUNTIME_THEME_DRIFT_DIAGNOSE_WF" ]] && grep -q 'workflow_dispatch:' "$RUNTIME_THEME_DRIFT_DIAGNOSE_WF"; then
    pass "[AC-020] Runtime theme drift diagnose workflow triggered via workflow_dispatch"
  else
    fail "[AC-020] Runtime theme drift diagnose workflow missing workflow_dispatch trigger"
  fi

  # AC-020: Runtime theme drift diagnose workflow runs the diagnose make lane
  if [[ -f "$RUNTIME_THEME_DRIFT_DIAGNOSE_WF" ]] \
    && grep -q 'make qa-runtime-theme-drift-diagnose' "$RUNTIME_THEME_DRIFT_DIAGNOSE_WF"; then
    pass "[AC-020] Runtime theme drift diagnose workflow runs qa-runtime-theme-drift-diagnose lane"
  else
    fail "[AC-020] Runtime theme drift diagnose workflow missing qa-runtime-theme-drift-diagnose invocation"
  fi

  # AC-020: CI static script list uses direct contracts (no workflow-wrapper verifiers)
  if [[ -f "$CI_STATIC_LIST" ]] && ! grep -Eq 'verify-.*-workflow\.sh$' "$CI_STATIC_LIST"; then
    pass "[AC-020] ci-scripts-static list excludes workflow-wrapper verifier scripts"
  else
    fail "[AC-020] ci-scripts-static still contains workflow-wrapper verifier scripts"
  fi

  # AC-020: CI static script list includes canonical direct contract checks
  if [[ -f "$CI_STATIC_LIST" ]]; then
    local required_scripts=(
      "verify-build-workflow-contract.sh"
      "verify-release-automation.sh"
      "verify-release-workflow-invocation.sh"
      "verify-release-dry-run-contract.sh"
      "verify-mfe-selector-hardening.sh"
      "verify-paragon-token-coverage.sh"
      "verify-no-latest-prod-tags.sh"
    )
    local found=0
    for script in "${required_scripts[@]}"; do
      if grep -q "$script" "$CI_STATIC_LIST" 2>/dev/null; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#required_scripts[@]}" ]]; then
      pass "[AC-020] ci-scripts-static includes all ${#required_scripts[@]} required direct contract scripts"
    else
      fail "[AC-020] ci-scripts-static missing direct contract scripts ($found/${#required_scripts[@]} found)"
    fi
  else
    fail "[AC-020] ci-scripts-static list missing: $CI_STATIC_LIST"
  fi
}

# ============================================================================
# SECTION: Security
# ============================================================================
check_security() {
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Security"
  echo "══════════════════════════════════════════════════════════════"

  # AC-005: TruffleHog secret scanning in CI
  if [[ -f "$CI_WF" ]] && grep -q 'trufflesecurity/trufflehog' "$CI_WF"; then
    pass "[AC-005] TruffleHog secret scanning configured in CI"
  else
    fail "[AC-005] TruffleHog secret scanning missing from CI"
  fi

  # AC-005: TruffleHog uses --only-verified
  if [[ -f "$CI_WF" ]] && grep -q '\-\-only-verified' "$CI_WF"; then
    pass "[AC-005] TruffleHog runs with --only-verified flag"
  else
    fail "[AC-005] TruffleHog missing --only-verified flag"
  fi

  # AC-027: Pre-commit secret scanning hook exists
  if [[ -f ".githooks/pre-commit" ]] && grep -q 'PASSWORD' .githooks/pre-commit; then
    pass "[AC-027] Pre-commit secret scanning hook exists and detects passwords"
  else
    fail "[AC-027] Pre-commit secret scanning hook missing or incomplete"
  fi

  # AC-027: Pre-commit detects API keys
  if [[ -f ".githooks/pre-commit" ]] && grep -qi 'api_key\|apikey\|API_KEY' .githooks/pre-commit; then
    pass "[AC-027] Pre-commit hook detects API key patterns"
  else
    fail "[AC-027] Pre-commit hook does not detect API key patterns"
  fi

  # AC-028: No raw echo of secrets in workflows
  local unsafe_echo=0
  for wf in "$WORKFLOWS_DIR"/*.yml; do
    if grep -E 'echo\s+\$\{\{.*secrets\.' "$wf" >/dev/null 2>&1; then
      fail "[AC-028] $(basename "$wf"): raw echo of secrets detected"
      unsafe_echo=$((unsafe_echo + 1))
    fi
  done
  if [[ "$unsafe_echo" -eq 0 ]]; then
    pass "[AC-028] No raw echo of secrets in any workflow"
  fi

  # AC-028: No set -x near secret usage
  local debug_leak=0
  for wf in "$WORKFLOWS_DIR"/*.yml; do
    if grep -B5 'secrets\.' "$wf" 2>/dev/null | grep -q 'set -x'; then
      fail "[AC-028] $(basename "$wf"): set -x near secret usage (may leak)"
      debug_leak=$((debug_leak + 1))
    fi
  done
  if [[ "$debug_leak" -eq 0 ]]; then
    pass "[AC-028] No set -x debug tracing near secret usage"
  fi

  # AC-006: prod tag guard is enforced (dedicated job OR consolidated static-validation script list)
  if [[ -f "$CI_WF" ]] && grep -q '^  prod-tag-guard:' "$CI_WF"; then
    pass "[AC-006] prod-tag-guard CI job exists (no :latest in prod overlays)"
  elif [[ -f ".github/ci-scripts-static.txt" ]] \
    && grep -q 'scripts/qa/verify-no-latest-prod-tags.sh' .github/ci-scripts-static.txt \
    && grep -q '^  static-validation:' "$CI_WF"; then
    pass "[AC-006] prod tag guard enforced via static-validation script bundle"
  else
    fail "[AC-006] prod-tag-guard CI job missing"
  fi

  # AC-006: verify-no-latest-prod-tags.sh exists
  if [[ -f "scripts/qa/verify-no-latest-prod-tags.sh" ]]; then
    pass "[AC-006] verify-no-latest-prod-tags.sh script exists"
  else
    fail "[AC-006] verify-no-latest-prod-tags.sh script missing"
  fi

  # Image scanning (Trivy or similar) in CI — not yet implemented
  local has_trivy=false
  for wf in "$WORKFLOWS_DIR"/*.yml; do
    if grep -qi 'trivy\|aquasecurity/trivy' "$wf" 2>/dev/null; then
      has_trivy=true
      break
    fi
  done
  if [[ "$has_trivy" == "true" ]]; then
    pass "[AC-009] Container image scanning (Trivy) configured in CI"
  else
    skip "[AC-009] Container image scanning (Trivy) not yet configured — add aquasecurity/trivy-action to build-tutor-images.yml after image build steps"
  fi

  # SBOM generation — not yet implemented
  local has_sbom=false
  for wf in "$WORKFLOWS_DIR"/*.yml; do
    if grep -qi 'sbom\|syft\|cyclonedx\|anchore/sbom-action' "$wf" 2>/dev/null; then
      has_sbom=true
      break
    fi
  done
  if [[ "$has_sbom" == "true" ]]; then
    pass "[AC-009] SBOM generation configured in CI"
  else
    skip "[AC-009] SBOM generation not yet configured — add anchore/sbom-action or syft to build-tutor-images.yml to generate SBOMs for openedx and mfe images"
  fi

  # Hadolint for Dockerfile linting
  if [[ -f "$CI_WF" ]] && grep -q 'hadolint' "$CI_WF"; then
    pass "[AC-005] Hadolint Dockerfile linting configured in CI"
  else
    fail "[AC-005] Hadolint Dockerfile linting missing from CI"
  fi

  # AC-001: CI workflow exists with required quality gates
  if [[ -f "$CI_WF" ]]; then
    if grep -q '^  static-validation:' "$CI_WF"; then
      pass "[AC-001] CI uses consolidated static-validation quality gate job"
    else
      local required_jobs=(
        "spec-lint"
        "branding-preflight"
        "monitoring-guardrails"
        "lint"
        "validate-k8s"
        "security-scan"
      )
      local job_found=0
      for job in "${required_jobs[@]}"; do
        if grep -q "^  ${job}:" "$CI_WF" 2>/dev/null; then
          job_found=$((job_found + 1))
        fi
      done
      if [[ "$job_found" -eq "${#required_jobs[@]}" ]]; then
        pass "[AC-001] All ${#required_jobs[@]} core CI quality gate jobs defined"
      else
        fail "[AC-001] Missing CI jobs ($job_found/${#required_jobs[@]} found)"
      fi
    fi
  else
    fail "[AC-001] CI workflow missing: $CI_WF"
  fi
}

# ============================================================================
# Main
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          CI/CD Pipeline Verification                       ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  @spec: ci-cd-pipeline_spec.md                             ║"
echo "║  Covers: AC-001, AC-005, AC-006, AC-009, AC-010, AC-011,  ║"
echo "║          AC-013, AC-014, AC-019, AC-020, AC-027, AC-028    ║"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "build" ]]; then
  check_build_pipeline
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "registry" ]]; then
  check_registry
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "gitops" ]]; then
  check_gitops
fi

if [[ -z "$SECTION_FILTER" || "$SECTION_FILTER" == "security" ]]; then
  check_security
fi

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  Summary"
echo "══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Passed:  $PASSED${NC}"
echo -e "  ${RED}Failed:  $FAILED${NC}"
echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
echo "══════════════════════════════════════════════════════════════"

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo -e "${RED}CI/CD pipeline verification failed ($FAILED failures).${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}CI/CD pipeline verification passed.${NC}"
if [[ "$SKIPPED" -gt 0 ]]; then
  echo -e "${YELLOW}Note: $SKIPPED check(s) skipped — see SKIP messages above for next steps.${NC}"
fi
exit 0
