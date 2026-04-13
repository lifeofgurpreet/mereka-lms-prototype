#!/usr/bin/env bash
# @covers AC-CI-BUILD-001
# @spec: ci-cd-pipeline_spec.md
#
# Verify build-tutor-images.yml contract:
#   - Workflow exists and has required inputs
#   - Image push targets GHCR only
#   - Digest pinning used in kustomization
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$REPO_ROOT}"
BUILD_WF="${BUILD_WF_OVERRIDE:-$REPO_ROOT/.github/workflows/build-tutor-images.yml}"
RELEASE_BUNDLE_BLOCK="$(sed -n '/^  release-bundle:/,/^  update-gitops:/p' "$BUILD_WF")"
UPDATE_GITOPS_BLOCK="$(sed -n '/^  update-gitops:/,$p' "$BUILD_WF")"
OPENEDX_CACHE_HEALTH_BLOCK="$(sed -n '/Verify OpenEdX build cache health/,/Generate image metadata/p' "$BUILD_WF")"
RESOLVE_SCOPE_BLOCK="$(sed -n '/^  resolve-build-scope:/,/^  lint:/p' "$BUILD_WF")"
SELECT_BUILD_LANE_BLOCK="$(sed -n '/^  select-build-lane:/,/^  prepare-build-context:/p' "$BUILD_WF")"
PREP_BLOCK="$(sed -n '/^  prepare-build-context:/,/^  build-openedx:/p' "$BUILD_WF")"
BUILD_OPENEDX_BLOCK="$(sed -n '/^  build-openedx:/,/^  build-mfe:/p' "$BUILD_WF")"
BUILD_MFE_BLOCK="$(sed -n '/^  build-mfe:/,/^  scan-openedx-image:/p' "$BUILD_WF")"
SCAN_OPENEDX_BLOCK="$(sed -n '/^  scan-openedx-image:/,/^  scan-mfe-image:/p' "$BUILD_WF")"
SCAN_MFE_BLOCK="$(sed -n '/^  scan-mfe-image:/,/^  slsa-provenance:/p' "$BUILD_WF")"

PASS=0 FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
path_filter_has_entry() {
  local entry="$1"
  grep -qF -- "      - '$entry'" "$BUILD_WF"
}
extract_step_block() {
  local block="$1"
  local needle="$2"
  awk -v needle="$needle" '
    capture && $0 ~ /^      - / && index($0, needle) == 0 { exit }
    index($0, needle) { capture=1 }
    capture { print }
  ' <<<"$block"
}

echo "=== Build Workflow Contract ==="

if [[ ! -f "$BUILD_WF" ]]; then
  fail "build-tutor-images.yml not found"
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
pass "build-tutor-images.yml exists"

# Check required inputs
if grep -q "target_environment" "$BUILD_WF"; then
  pass "target_environment input defined"
else
  fail "target_environment input missing"
fi

if grep -q "update_gitops" "$BUILD_WF"; then
  pass "update_gitops input defined"
else
  fail "update_gitops input missing"
fi

if grep -q "build_profile" "$BUILD_WF"; then
  pass "build_profile input defined"
else
  fail "build_profile input missing"
fi

# Manual build-proof dispatches must skip release-bundle generation when the
# placeholder environment is still selected.
if [[ "$RELEASE_BUNDLE_BLOCK" == *"inputs.target_environment != 'select-environment'"* && "$RELEASE_BUNDLE_BLOCK" == *"inputs.build_profile == 'proof'"* ]]; then
  pass "release bundle job skips placeholder manual environment and non-proof manual profiles"
else
  fail "release bundle job missing placeholder-environment/non-proof skip gate"
fi

if [[ "$RELEASE_BUNDLE_BLOCK" == *"target_environment must be explicitly selected before generating a release bundle"* ]]; then
  fail "release bundle job still hard-fails on placeholder manual environment"
else
  pass "release bundle job no longer hard-fails on placeholder manual environment"
fi

if grep -q 'contracts/promotion-dispatch-envelope-schema.yaml' "$BUILD_WF"; then
  pass "workflow fetches PCP promotion-dispatch-envelope schema"
else
  fail "workflow missing PCP promotion-dispatch-envelope schema fetch"
fi

if grep -q '"dispatch_event_type": "promote-mereka-lms-dev"' "$BUILD_WF"; then
  pass "dispatch envelope records canonical dispatch_event_type"
else
  fail "dispatch envelope missing canonical dispatch_event_type"
fi

if grep -q '"delivery_lane": "dev"' "$BUILD_WF" && grep -q '"lane": "mereka-lms"' "$BUILD_WF" && grep -q '"service_id": "mereka-lms"' "$BUILD_WF"; then
  pass "dispatch envelope records canonical lane/service identity"
else
  fail "dispatch envelope missing canonical lane/service identity"
fi

if grep -q '"control_plane_ref": contract_ref' "$BUILD_WF" && grep -q '"contract_family": contract_family' "$BUILD_WF" && grep -q '"contract_version": contract_version' "$BUILD_WF"; then
  pass "dispatch envelope carries PCP contract handshake provenance"
else
  fail "dispatch envelope missing PCP contract handshake provenance"
fi

if grep -Fq '"event_type": evidence["dispatch_event_type"]' "$BUILD_WF"; then
  pass "repository_dispatch event_type is derived from canonical envelope"
else
  fail "repository_dispatch event_type must be derived from canonical envelope"
fi

# Workflow consistency must compare canonical lane names, not raw workflow aliases.
if grep -q "normalize_lane_to_canonical" "$BUILD_WF" && grep -q "scripts/lib/lane-normalize.sh" "$BUILD_WF"; then
  pass "workflow normalizes target_environment to canonical lane"
else
  fail "workflow missing canonical target_environment normalization"
fi

if [[ "$UPDATE_GITOPS_BLOCK" == *"github.event_name == 'workflow_dispatch' && inputs.update_gitops && inputs.target_environment != 'select-environment' && inputs.build_profile == 'proof'"* ]]; then
  pass "update-gitops job is gated on explicit proof-profile manual dispatch inputs"
else
  fail "update-gitops job missing explicit proof-profile manual-dispatch gating"
fi

if [[ "$UPDATE_GITOPS_BLOCK" == *"github.event_name == 'push' && github.ref == 'refs/heads/main'"* ]]; then
  fail "update-gitops job still auto-runs on push to main"
else
  pass "update-gitops job no longer auto-runs on push to main"
fi

# Check container registry push target (GHCR only)
if grep -q "ghcr.io" "$BUILD_WF"; then
  pass "Container registry push target is GHCR"
else
  fail "Container registry push target missing (expected ghcr.io)"
fi

if grep -q "asia-southeast1-docker.pkg.dev" "$BUILD_WF"; then
  fail "Legacy GAR push target found (workflow must publish to GHCR only)"
else
  pass "No legacy GAR push targets remain"
fi

# Check permissions block
if grep -q "permissions:" "$BUILD_WF"; then
  pass "permissions block present"
else
  fail "permissions block missing"
fi

# Workflow path filter must include the exact image-bearing paths and helper
# scripts the workflow executes. Broad globs here create expensive build fan-out
# for docs/proof-only changes.
required_trigger_paths=(
  "requirements-tutor.txt"
  ".github/actions/setup-python-env/**"
  "infrastructure/tutor/config.example.yml"
  "infrastructure/tutor/apply-patches.sh"
  "infrastructure/tutor/patches/**"
  "infrastructure/tutor/custom-apps/**"
  "infrastructure/tutor/plugins/**"
  "infrastructure/tutor/themes/**"
  "infrastructure/tutor/brand-*/**"
  "assets/branding/**"
  "scripts/infra/prepare-tutor-build-context.sh"
  "scripts/infra/prepare-tutor-build-context-ci.sh"
  "infrastructure/tutor/apply-patches.sh"
  "infrastructure/tutor/patches/**"
  "scripts/infra/resolve-build-scope.sh"
  "scripts/infra/install-cosign.sh"
  "scripts/infra/install-trivy.sh"
  "scripts/infra/generate-build-provenance.sh"
  "scripts/infra/generate-release-bundle.sh"
  "scripts/release/generate_release_object.py"
  "scripts/release/release_object_bindings.py"
  "scripts/infra/build-openedx-image.sh"
  "scripts/infra/build-mfe-image.sh"
  "scripts/infra/release-openedx-gitops.sh"
  "scripts/infra/resolve-image-digest.sh"
  "scripts/lib/lane-normalize.sh"
  "scripts/qa/verify-build-provenance.sh"
  "scripts/qa/verify-openedx-image-branding.sh"
  "scripts/qa/verify-release-bundle.sh"
  "scripts/qa/verify-release-object.sh"
  "scripts/qa/verify-mfe-image-branding.sh"
  "scripts/qa/verify-mfe-runtime-contract.sh"
)
for trigger_path in "${required_trigger_paths[@]}"; do
  if path_filter_has_entry "$trigger_path"; then
    pass "workflow path filter includes $trigger_path"
  else
    fail "workflow path filter missing $trigger_path"
  fi
done

if [[ -f "$REPO_ROOT/scripts/infra/resolve-build-scope.sh" ]]; then
  pass "resolve-build-scope helper exists"
else
  fail "resolve-build-scope helper missing"
fi

if [[ -f "$REPO_ROOT/.github/actions/select-build-lane/action.yml" ]]; then
  pass "select-build-lane action exists"
else
  fail "select-build-lane action missing"
fi

if [[ -x "$REPO_ROOT/scripts/infra/build-openedx-image.sh" ]]; then
  pass "build-openedx-image helper exists"
else
  fail "build-openedx-image helper missing or not executable"
fi

if [[ -x "$REPO_ROOT/scripts/infra/build-mfe-image.sh" ]]; then
  pass "build-mfe-image helper exists"
else
  fail "build-mfe-image helper missing or not executable"
fi

if [[ -x "$REPO_ROOT/scripts/infra/prepare-tutor-build-context.sh" ]]; then
  pass "prepare-tutor-build-context helper exists"
else
  fail "prepare-tutor-build-context helper missing or not executable"
fi

if [[ -x "$REPO_ROOT/scripts/infra/prepare-tutor-build-context-ci.sh" ]]; then
  pass "prepare-tutor-build-context-ci helper exists"
else
  fail "prepare-tutor-build-context-ci helper missing or not executable"
fi

if [[ -x "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh" ]]; then
  pass "verify-openedx-image-branding helper exists"
else
  fail "verify-openedx-image-branding helper missing or not executable"
fi

if grep -q 'DOCKER_PULL_TIMEOUT_SECS=' "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh" \
  && grep -q 'run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull' "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh" \
  && grep -q 'run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run' "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh" \
  && ! grep -q 'if ! run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull' "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh" \
  && ! grep -q 'if ! run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run' "$REPO_ROOT/scripts/qa/verify-openedx-image-branding.sh"; then
  pass "verify-openedx-image-branding helper bounds docker pull/run with timeouts"
else
  fail "verify-openedx-image-branding helper missing safe docker timeout guards"
fi

if [[ -x "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" ]]; then
  pass "verify-mfe-image-branding helper exists"
else
  fail "verify-mfe-image-branding helper missing or not executable"
fi

if grep -q 'DOCKER_PULL_TIMEOUT_SECS=' "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" \
  && grep -q 'run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull' "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" \
  && grep -q 'run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run' "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" \
  && ! grep -q 'if ! run_with_timeout "${DOCKER_PULL_TIMEOUT_SECS}" docker pull' "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh" \
  && ! grep -q 'if ! run_with_timeout "${DOCKER_RUN_TIMEOUT_SECS}" docker run' "$REPO_ROOT/scripts/qa/verify-mfe-image-branding.sh"; then
  pass "verify-mfe-image-branding helper bounds docker pull/run with timeouts"
else
  fail "verify-mfe-image-branding helper missing safe docker timeout guards"
fi

if [[ "$RESOLVE_SCOPE_BLOCK" == *"./scripts/infra/resolve-build-scope.sh"* ]]; then
  pass "workflow resolves push build scope via canonical helper"
else
  fail "workflow missing canonical resolve-build-scope helper call"
fi

if [[ "$RESOLVE_SCOPE_BLOCK" == *"fetch-depth: 0"* ]]; then
  pass "build-scope resolver uses full git history for diff safety"
else
  fail "build-scope resolver missing fetch-depth: 0"
fi

if [[ "$SELECT_BUILD_LANE_BLOCK" == *"uses: ./.github/actions/select-build-lane"* ]]; then
  pass "workflow selects heavy-build lane via repo-local action"
else
  fail "workflow missing repo-local select-build-lane action"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *"needs.resolve-build-scope.outputs.build_openedx == 'true'"* ]]; then
  pass "build-openedx job is gated by resolved build scope"
else
  fail "build-openedx job missing resolved build-scope gate"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *"select-build-lane"* && "$BUILD_OPENEDX_BLOCK" == *"runs-on: \${{ needs.select-build-lane.outputs.runner_label }}"* ]]; then
  pass "build-openedx job consumes select-build-lane runner output"
else
  fail "build-openedx job missing select-build-lane runner contract"
fi

if [[ "$BUILD_MFE_BLOCK" == *"needs.resolve-build-scope.outputs.build_mfe == 'true'"* ]]; then
  pass "build-mfe job is gated by resolved build scope"
else
  fail "build-mfe job missing resolved build-scope gate"
fi

if [[ "$BUILD_MFE_BLOCK" == *"select-build-lane"* && "$BUILD_MFE_BLOCK" == *"runs-on: \${{ needs.select-build-lane.outputs.runner_label }}"* ]]; then
  pass "build-mfe job consumes select-build-lane runner output"
else
  fail "build-mfe job missing select-build-lane runner contract"
fi

# Fastlane (PR #1518, #1524) moves lightweight orchestration jobs to
# GitHub-hosted runners to save ARC capacity for the actual heavy builds.
# Accept either ARC runners or ubuntu-* hosted runners for prep — the
# invariant that matters is that the canonical prep script runs.
if [[ ( "$PREP_BLOCK" == *'runs-on: mereka-k8s-runners'* || "$PREP_BLOCK" == *'runs-on: ubuntu-'* ) \
   && "$PREP_BLOCK" == *'./scripts/infra/prepare-tutor-build-context-ci.sh --target "${{ steps.prep-target.outputs.target }}"'* ]]; then
  pass "prepare-build-context job runs canonical prep (ARC or hosted — fastlane-compatible)"
else
  fail "prepare-build-context job missing canonical prep contract"
fi

if [[ "$PREP_BLOCK" == *'target=all'* && "$PREP_BLOCK" == *'target=openedx'* && "$PREP_BLOCK" == *'target=mfe'* ]]; then
  pass "prepare-build-context job resolves all/openedx/mfe prep targets"
else
  fail "prepare-build-context job missing target-resolution contract"
fi

if [[ "$PREP_BLOCK" == *'openedx-build-context.tgz'* && "$PREP_BLOCK" == *'mfe-build-context.tgz'* && "$PREP_BLOCK" == *'tutor-build-contexts'* ]]; then
  pass "prepare-build-context job packages target-specific artifacts into one shared bundle"
else
  fail "prepare-build-context job missing shared build-context bundle contract"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'prepare-build-context'* ]]; then
  pass "build-openedx job depends on prepared build context"
else
  fail "build-openedx job missing prepared build-context dependency"
fi

if [[ "$BUILD_MFE_BLOCK" == *'prepare-build-context'* ]]; then
  pass "build-mfe job depends on prepared build context"
else
  fail "build-mfe job missing prepared build-context dependency"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'actions/download-artifact'* && "$BUILD_OPENEDX_BLOCK" == *'tutor-build-contexts'* && "$BUILD_OPENEDX_BLOCK" == *'openedx-build-context.tgz'* ]]; then
  pass "build-openedx job downloads shared prepared build-context artifact"
else
  fail "build-openedx job missing shared prepared build-context artifact download"
fi

if [[ "$BUILD_MFE_BLOCK" == *'actions/download-artifact'* && "$BUILD_MFE_BLOCK" == *'tutor-build-contexts'* && "$BUILD_MFE_BLOCK" == *'mfe-build-context.tgz'* ]]; then
  pass "build-mfe job downloads shared prepared build-context artifact"
else
  fail "build-mfe job missing shared prepared build-context artifact download"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'Set up Python environment'* || "$BUILD_OPENEDX_BLOCK" == *'Set up Tutor environment'* ]]; then
  fail "build-openedx job still performs Tutor prep on heavy builders"
else
  pass "build-openedx heavy builder no longer performs Tutor prep"
fi

if [[ "$BUILD_MFE_BLOCK" == *'Set up Python environment'* || "$BUILD_MFE_BLOCK" == *'Set up Tutor environment'* ]]; then
  fail "build-mfe job still performs Tutor prep on heavy builders"
else
  pass "build-mfe heavy builder no longer performs Tutor prep"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'./infrastructure/tutor/apply-patches.sh'* || "$BUILD_MFE_BLOCK" == *'./infrastructure/tutor/apply-patches.sh'* ]]; then
  fail "heavy build jobs still call apply-patches.sh directly"
else
  pass "heavy build jobs no longer call apply-patches.sh directly"
fi

required_trigger_exclusions=(
  "!infrastructure/tutor/**/*.md"
  "!infrastructure/tutor/mfe-build/**"
)
for trigger_exclusion in "${required_trigger_exclusions[@]}"; do
  if path_filter_has_entry "$trigger_exclusion"; then
    pass "workflow path filter excludes $trigger_exclusion"
  else
    fail "workflow path filter missing exclusion $trigger_exclusion"
  fi
done

broad_trigger_globs=(
  "deploy/k8s/base/apps/openedx/**"
  "infrastructure/tutor/**"
  "scripts/infra/**"
  "scripts/lib/**"
)
for broad_glob in "${broad_trigger_globs[@]}"; do
  if path_filter_has_entry "$broad_glob"; then
    fail "workflow path filter still includes broad trigger glob $broad_glob"
  else
    pass "workflow path filter avoids broad trigger glob $broad_glob"
  fi
done

# App-owned proof must route through lms-ops in build workflow
if grep -qE '\./bin/lms-ops[[:space:]]+proof' "$BUILD_WF"; then
  pass "build workflow emits app proof via bin/lms-ops"
else
  fail "build workflow missing bin/lms-ops proof emission"
fi

# Promotion artifact upload must include release-gate envelope
if grep -q "var/ci/release-gate-envelope.json" "$BUILD_WF"; then
  pass "build workflow uploads release-gate envelope artifact"
else
  fail "build workflow missing release-gate envelope artifact upload"
fi

if [[ "$UPDATE_GITOPS_BLOCK" == *'./scripts/qa/verify-release-object.sh var/ci/release-object.json'* && "$UPDATE_GITOPS_BLOCK" == *'scripts/release/release_object_bindings.py'* && "$UPDATE_GITOPS_BLOCK" == *'promotion-inputs'* ]]; then
  pass "update-gitops job re-validates the downloaded release object before promotion"
else
  fail "update-gitops job missing release object consumer validation gate"
fi

PROMOTION_STEP_BLOCK="$(extract_step_block "$UPDATE_GITOPS_BLOCK" './scripts/infra/release-openedx-gitops.sh')"
if [[ "$PROMOTION_STEP_BLOCK" == *'./scripts/infra/release-openedx-gitops.sh'* && "$PROMOTION_STEP_BLOCK" == *'--release-object-json var/ci/release-object.json'* ]]; then
  pass "update-gitops job binds release object into promotion step"
else
  fail "update-gitops job missing release-object binding on promotion step"
fi

PROOF_STEP_BLOCK="$(extract_step_block "$UPDATE_GITOPS_BLOCK" './bin/lms-ops proof')"
if [[ "$PROOF_STEP_BLOCK" == *'./bin/lms-ops proof'* && "$PROOF_STEP_BLOCK" == *'--release-object-json var/ci/release-object.json'* ]]; then
  pass "update-gitops job binds release object into proof step"
else
  fail "update-gitops job missing release-object binding on proof step"
fi

if [[ "$UPDATE_GITOPS_BLOCK" == *'verify-proof-envelope'* && "$UPDATE_GITOPS_BLOCK" == *'--envelope-json var/proof/release-gate.json'* ]]; then
  pass "update-gitops job verifies release-gate envelope binding against release object"
else
  fail "update-gitops job missing proof-envelope release binding verification"
fi

# Informational SBOM generation must be bounded so it cannot occupy the main
# image-build lane indefinitely, and it must run off the heavy builders.
if [[ "$BUILD_OPENEDX_BLOCK" == *"Generate SBOM for OpenEdX image"* || "$BUILD_OPENEDX_BLOCK" == *"Scan OpenEdX image for vulnerabilities"* || "$BUILD_OPENEDX_BLOCK" == *"Install Trivy CLI"* ]]; then
  fail "OpenEdX image scanning still runs inside the heavy build job"
else
  pass "OpenEdX heavy build job no longer performs SBOM/Trivy scanning"
fi

if [[ "$BUILD_MFE_BLOCK" == *"Generate SBOM for MFE image"* || "$BUILD_MFE_BLOCK" == *"Scan MFE image for vulnerabilities"* || "$BUILD_MFE_BLOCK" == *"Install Trivy CLI"* ]]; then
  fail "MFE image scanning still runs inside the heavy build job"
else
  pass "MFE heavy build job no longer performs SBOM/Trivy scanning"
fi

if [[ "$SCAN_OPENEDX_BLOCK" == *"runs-on: mereka-k8s-heavy-builders"* && "$SCAN_OPENEDX_BLOCK" == *"needs: [build-openedx]"* ]]; then
  pass "OpenEdX post-push scan runs on heavy builders after build-openedx"
else
  fail "OpenEdX post-push scan job missing canonical runner or dependency"
fi

if [[ "$SCAN_MFE_BLOCK" == *"runs-on: mereka-k8s-heavy-builders"* && "$SCAN_MFE_BLOCK" == *"needs: [build-mfe]"* ]]; then
  pass "MFE post-push scan runs on heavy builders after build-mfe"
else
  fail "MFE post-push scan job missing canonical runner or dependency"
fi

if [[ "$SCAN_OPENEDX_BLOCK" == *'uses: docker/setup-buildx-action'* && "$SCAN_OPENEDX_BLOCK" == *'Fix DinD network MTU'* ]]; then
  pass "OpenEdX post-push scan establishes canonical Docker runtime"
else
  fail "OpenEdX post-push scan missing canonical Docker/MTU setup"
fi

if [[ "$SCAN_MFE_BLOCK" == *'uses: docker/setup-buildx-action'* && "$SCAN_MFE_BLOCK" == *'Fix DinD network MTU'* ]]; then
  pass "MFE post-push scan establishes canonical Docker runtime"
else
  fail "MFE post-push scan missing canonical Docker/MTU setup"
fi

if grep -q 'timeout 20m "\$HOME/\.local/bin/syft" scan "registry:\${OPENEDX_IMAGE_REF}"' "$BUILD_WF"; then
  pass "OpenEdX post-push SBOM generation has a timeout guard"
else
  fail "OpenEdX post-push SBOM generation missing timeout guard"
fi

if [[ "$SCAN_OPENEDX_BLOCK" == *'timeout 20m trivy image'* && "$SCAN_OPENEDX_BLOCK" == *'OpenEdX Trivy scan timed out after 20m'* ]]; then
  pass "OpenEdX post-push Trivy scan has a timeout guard"
else
  fail "OpenEdX post-push Trivy scan missing timeout guard"
fi

if grep -q 'timeout 20m "\$HOME/\.local/bin/syft" scan "registry:\${MFE_IMAGE_REF}"' "$BUILD_WF"; then
  pass "MFE post-push SBOM generation has a timeout guard"
else
  fail "MFE post-push SBOM generation missing timeout guard"
fi

if [[ "$SCAN_MFE_BLOCK" == *'timeout 20m trivy image'* && "$SCAN_MFE_BLOCK" == *'MFE Trivy scan timed out after 20m'* ]]; then
  pass "MFE post-push Trivy scan has a timeout guard"
else
  fail "MFE post-push Trivy scan missing timeout guard"
fi

if [[ "$SCAN_OPENEDX_BLOCK" == *'${{ env.REGISTRY }}/openedx@${{ needs.build-openedx.outputs.image_digest }}'* ]]; then
  pass "OpenEdX post-push scan uses resolved pushed digest"
else
  fail "OpenEdX post-push scan missing resolved digest image ref"
fi

if [[ "$SCAN_OPENEDX_BLOCK" == *'Verify OpenEdX image branding contract'* && "$SCAN_OPENEDX_BLOCK" == *'scripts/qa/verify-openedx-image-branding.sh "${OPENEDX_IMAGE_REF}"'* ]]; then
  pass "OpenEdX branding verification runs post-push via canonical registry-image helper"
else
  fail "OpenEdX branding verification missing canonical post-push helper call"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'Verify OpenEdX image branding contract'* ]]; then
  fail "OpenEdX branding verification still runs inside the heavy build job"
else
  pass "OpenEdX heavy build job no longer performs branding verification"
fi

if [[ "$SCAN_MFE_BLOCK" == *'${{ env.REGISTRY }}/mfe@${{ needs.build-mfe.outputs.image_digest }}'* ]]; then
  pass "MFE post-push scan uses resolved pushed digest"
else
  fail "MFE post-push scan missing resolved digest image ref"
fi

if [[ "$SCAN_MFE_BLOCK" == *'Verify MFE image branding contract'* && "$SCAN_MFE_BLOCK" == *'scripts/qa/verify-mfe-image-branding.sh "${MFE_IMAGE_REF}"'* ]]; then
  pass "MFE branding verification runs post-push via canonical registry-image helper"
else
  fail "MFE branding verification missing canonical post-push helper call"
fi

if [[ "$SCAN_MFE_BLOCK" == *'Verify MFE runtime contract (image)'* && "$SCAN_MFE_BLOCK" == *'scripts/qa/verify-mfe-runtime-contract.sh --image "${MFE_IMAGE_REF}"'* ]]; then
  pass "MFE runtime verification runs post-push via canonical registry-image helper"
else
  fail "MFE runtime verification missing canonical post-push helper call"
fi

if [[ "$BUILD_MFE_BLOCK" == *'Verify MFE image branding contract'* ]]; then
  fail "MFE branding verification still runs inside the heavy build job"
else
  pass "MFE heavy build job no longer performs branding verification"
fi

if [[ "$BUILD_MFE_BLOCK" == *'Verify MFE runtime contract (image)'* ]]; then
  fail "MFE image runtime verification still runs inside the heavy build job"
else
  pass "MFE heavy build job no longer performs image runtime verification"
fi

if [[ "$BUILD_MFE_BLOCK" == *'./scripts/infra/build-mfe-image.sh'* ]]; then
  pass "MFE build uses the canonical push-first helper"
else
  fail "MFE build missing canonical push-first helper"
fi

if [[ "$BUILD_MFE_BLOCK" == *'--build-profile "${BUILD_PROFILE}"'* ]]; then
  pass "MFE build passes explicit build profile to the helper"
else
  fail "MFE build missing explicit build profile"
fi

if [[ "$BUILD_MFE_BLOCK" == *'tutor images build mfe'* ]]; then
  fail "MFE build still calls tutor images build mfe directly"
else
  pass "MFE build no longer calls tutor images build mfe directly"
fi

if [[ "$BUILD_MFE_BLOCK" == *'MFE_LOCAL_IMAGE'* ]]; then
  fail "MFE build still depends on a local daemon image"
else
  pass "MFE build no longer depends on a local daemon image"
fi

if [[ "$RELEASE_BUNDLE_BLOCK" == *"scan-openedx-image"* && "$RELEASE_BUNDLE_BLOCK" == *"scan-mfe-image"* ]]; then
  pass "release bundle waits for post-push scan artifact jobs"
else
  fail "release bundle missing post-push scan dependencies"
fi

if [[ "$RELEASE_BUNDLE_BLOCK" == *'scripts/release/generate_release_object.py'* ]]; then
  pass "release bundle job emits the canonical release object"
else
  fail "release bundle job missing release object generation"
fi

if [[ "$RELEASE_BUNDLE_BLOCK" == *'scripts/qa/verify-release-object.sh'* ]]; then
  pass "release bundle job verifies the canonical release object"
else
  fail "release bundle job missing release object verification"
fi

if [[ "$RELEASE_BUNDLE_BLOCK" == *'var/ci/release-object.json'* ]]; then
  pass "release bundle artifact upload includes release-object.json"
else
  fail "release bundle artifact upload missing release-object.json"
fi

# OpenEdX cache-health reporting must match the canonical push-first strategy:
# docker-container + GHA cache read/write + registry fallback.
if [[ "$OPENEDX_CACHE_HEALTH_BLOCK" == *"GHA cache read/write is enabled for OpenEdX build"* ]]; then
  pass "OpenEdX cache health reports the canonical GHA-backed strategy"
else
  fail "OpenEdX cache health missing canonical GHA-backed strategy messaging"
fi

if [[ "$OPENEDX_CACHE_HEALTH_BLOCK" == *"GHA cache exporters intentionally absent for OpenEdX build"* ]]; then
  fail "OpenEdX cache health still reports the stale non-GHA strategy"
else
  pass "OpenEdX cache health no longer treats GHA cache exporters as forbidden"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'./scripts/infra/build-openedx-image.sh'* ]]; then
  pass "OpenEdX build uses the canonical push-first helper"
else
  fail "OpenEdX build missing canonical push-first helper"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'--build-profile "${BUILD_PROFILE}"'* ]]; then
  pass "OpenEdX build passes explicit build profile to the helper"
else
  fail "OpenEdX build missing explicit build profile"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'tutor images build openedx'* ]]; then
  fail "OpenEdX build still calls tutor images build openedx directly"
else
  pass "OpenEdX build no longer calls tutor images build openedx directly"
fi

if [[ "$BUILD_OPENEDX_BLOCK" == *'OPENEDX_LOCAL_IMAGE'* ]]; then
  fail "OpenEdX build still depends on a local daemon image"
else
  pass "OpenEdX build no longer depends on a local daemon image"
fi

# Workflow wording must not claim mutable-tag auto-deploy ownership anymore.
if grep -q "dev auto-deploy" "$BUILD_WF" || grep -q "auto-deploys via ArgoCD" "$BUILD_WF"; then
  fail "build workflow still claims mutable-tag dev auto-deploy semantics"
else
  pass "build workflow no longer claims mutable-tag dev auto-deploy semantics"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ $FAIL -gt 0 ]] && exit 1
exit 0
