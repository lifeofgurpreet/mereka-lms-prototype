#!/usr/bin/env bash
# @covers mereka-lms-build-scope-classifier
# @spec: scripts/infra/resolve-build-scope.sh
#
# Self-test for resolve-build-scope.sh. Runs a matrix of representative
# input paths and asserts each classifies to the correct scope label.
# Added with the PR that fixed over-triggering on config/docs-only PRs
# (see docs/ops/evidence/build-tutor-images-over-triggering-regression-2026-04-20.md).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESOLVER="$REPO_ROOT/scripts/infra/resolve-build-scope.sh"

PASS=0
FAIL=0

# Extract the "Scope label: `X`" value from the resolver's markdown output.
scope_for() {
  local input="$1"
  printf '%s\n' "$input" \
    | bash "$RESOLVER" \
    | grep -oE 'Scope label: `[^`]+`' \
    | head -1 \
    | sed 's/Scope label: `//; s/`//'
}

expect() {
  local description="$1"
  local expected="$2"
  local input="$3"
  local actual
  actual="$(scope_for "$input" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf '  PASS %s (got %s)\n' "$description" "$actual"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %s (expected %s, got %s)\n' "$description" "$expected" "$actual"
  fi
}

echo "=== resolve-build-scope classifier matrix ==="

# --- skip cases (non-image changes should not rebuild anything) ---
expect "docs .md"                          "skip"         "docs/status/active/CURRENT-OPERATOR-STATE.md"
expect "top-level README"                  "skip"         "README.md"
expect "AGENTS.md"                         "skip"         "AGENTS.md"
expect "CLAUDE.md"                         "skip"         "CLAUDE.md"
expect "beads jsonl"                       "skip"         ".beads/issues.jsonl"
expect "generic verify script"             "skip"         "scripts/qa/verify-tenant-foundation.sh"
expect "governance registry"               "skip"         "scripts/governance/script-registry.yaml"
expect "infra release script"              "skip"         "scripts/infra/release-openedx-gitops.sh"
expect "infra verify script"               "skip"         "scripts/infra/verify-release-preflight.sh"
expect "base kustomize manifest"           "skip"         "deploy/k8s/base/kustomization.yaml"
expect "local overlay"                     "skip"         "deploy/k8s/overlays/local/kustomization.yaml"
expect ".github workflow"                  "skip"         ".github/workflows/ci.yml"
expect "reports directory"                 "skip"         "reports/2026/audits/sample.md"
expect "verification catalog"              "skip"         "verification/catalogs/VERIFICATION_CATALOG.md"
expect "evals prompt"                      "skip"         "evals/evals.yaml"
expect "tests directory"                   "skip"         "tests/integration/sample.py"
expect "specs"                             "skip"         "specs/secrets-management.md"
expect "tutor_env (gitignored)"            "skip"         "tutor_env/config.yml"

# --- openedx-owned ---
expect "openedx base settings"             "openedx-only" "deploy/k8s/base/apps/openedx/settings/lms/production.py"
expect "openedx dockerfile plugin"         "openedx-only" "infrastructure/tutor/plugins/_mereka_lms/openedx_dockerfile.py"
expect "openedx branding verifier"         "openedx-only" "scripts/qa/verify-openedx-image-branding.sh"
expect "mereka theme lms"                  "openedx-only" "infrastructure/tutor/themes/mereka/lms/static/sass/override.scss"
expect "multi-tenancy plugin"              "openedx-only" "infrastructure/tutor/plugins/multi-tenancy/plugin.py"

# --- mfe-owned ---
expect "mfe theme"                         "mfe-only"     "infrastructure/tutor/themes/mereka/mfe/brand.scss"
expect "mfe dockerfile plugin"             "mfe-only"     "infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
expect "mfe slot registration"             "mfe-only"     "infrastructure/tutor/plugins/mereka_lms_mfe_slots.py"
expect "mfe runtime js"                    "mfe-only"     "infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/tenant-resolution-runtime.js"
expect "mfe branding verifier"             "mfe-only"     "scripts/qa/verify-mfe-image-branding.sh"
expect "mfe footer plugin slot verifier"   "mfe-only"     "scripts/qa/verify-mfe-footer-plugin-slot.sh"
expect "mfe runtime helper contract"       "mfe-only"     "scripts/qa/verify-mfe-runtime-helper-contract.sh"

# --- shared / ambiguous (still builds both) ---
expect "random unclassified python file"   "both"         "some/unknown/file.py"
expect "infrastructure/tutor/apply-patches.sh" "both"     "infrastructure/tutor/apply-patches.sh"

# --- safety fallback (no changed files at all) ---
expected="both"
actual=$(bash "$RESOLVER" </dev/null | grep -oE 'Scope label: `[^`]+`' | head -1 | sed 's/Scope label: `//; s/`//')
if [[ "$actual" == "$expected" ]]; then
  PASS=$((PASS + 1))
  printf '  PASS empty input safety fallback (got %s)\n' "$actual"
else
  FAIL=$((FAIL + 1))
  printf '  FAIL empty input safety fallback (expected %s, got %s)\n' "$expected" "$actual"
fi

echo ""
echo "=== Result: $PASS PASS / $FAIL FAIL ==="
[[ "$FAIL" -eq 0 ]] || exit 1
