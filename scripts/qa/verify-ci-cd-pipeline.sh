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
POLICY_WF=".github/workflows/policy-checks.yml"
EVIDENCE_WF=".github/workflows/release-evidence.yml"
RELEASE_SCRIPT="scripts/infra/release-openedx-gitops.sh"
DIGEST_HELPER="scripts/infra/resolve-image-digest.sh"
WORKFLOWS_DIR=".github/workflows"

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
  if [[ -f "requirements-tutor.txt" ]] \
    && grep -q 'tutor\[full\]==18.2.2' requirements-tutor.txt \
    && grep -q 'tutor-mfe==18.1.0' requirements-tutor.txt \
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

  # AC-009: Image push targets correct registry
  if grep -q 'asia-southeast1-docker.pkg.dev/mereka-lms/openedx' "$BUILD_WF"; then
    pass "[AC-009] Images push to correct Artifact Registry (asia-southeast1)"
  else
    fail "[AC-009] Images do not target correct Artifact Registry"
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

  # AC-009: GCP auth configured (direct action or local composite auth wrapper)
  if grep -qE 'google-github-actions/auth@(v2|[0-9a-f]{40})(\s*#\s*v2)?' "$BUILD_WF" \
    || grep -q '\./\.github/actions/gcp-gke-auth' "$BUILD_WF"; then
    pass "[AC-009] GCP authentication configured (direct action or gcp-gke-auth composite)"
  else
    fail "[AC-009] GCP authentication missing from build workflow"
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

  # AC-020: Policy checks workflow exists
  if [[ -f "$POLICY_WF" ]]; then
    pass "[AC-020] Policy checks workflow exists"
  else
    fail "[AC-020] Policy checks workflow missing: $POLICY_WF"
  fi

  # AC-020: Policy checks is workflow_dispatch only
  if [[ -f "$POLICY_WF" ]] && grep -q 'workflow_dispatch:' "$POLICY_WF"; then
    pass "[AC-020] Policy checks triggered via workflow_dispatch"
  else
    fail "[AC-020] Policy checks missing workflow_dispatch trigger"
  fi

  # AC-020: Policy checks run all required verification scripts
  if [[ -f "$POLICY_WF" ]]; then
    local required_scripts=(
      "verify-release-automation.sh"
      "verify-build-workflow-contract.sh"
      "verify-release-workflow-invocation.sh"
      "verify-release-dry-run-contract.sh"
      "verify-release-evidence-workflow.sh"
      "verify-a11y-tenant-branding-workflow.sh"
      "verify-certificate-branding-workflow.sh"
      "verify-email-template-branding-workflow.sh"
      "verify-mfe-selector-hardening-workflow.sh"
      "verify-paragon-runtime-contract-workflow.sh"
      "verify-paragon-theme-budget-workflow.sh"
      "verify-cross-browser-branding-workflow.sh"
      "verify-npm-start-smoke-workflow.sh"
      "verify-frontend-performance-spotcheck-workflow.sh"
      "verify-frontend-branding-closure-workflow.sh"
      "verify-mfe-live-dom-audit-workflow.sh"
      "verify-phase7-dom-audit-contract.sh"
      "verify-accessibility-audit-workflow.sh"
      "verify-a11y-runtime-lane-contract.sh"
      "verify-no-latest-prod-tags.sh"
    )
    local found=0
    for script in "${required_scripts[@]}"; do
      if grep -q "$script" "$POLICY_WF" 2>/dev/null; then
        found=$((found + 1))
      fi
    done
    if [[ "$found" -eq "${#required_scripts[@]}" ]]; then
      pass "[AC-020] Policy checks run all ${#required_scripts[@]} required verification scripts"
    else
      fail "[AC-020] Policy checks missing scripts ($found/${#required_scripts[@]} found)"
    fi
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
