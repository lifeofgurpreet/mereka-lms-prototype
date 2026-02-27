#!/usr/bin/env bash
# @covers AC-001, AC-003, AC-004, AC-005, AC-006, AC-030, AC-031
# @spec: enterprise-microservices_spec.md
# Static integrity guard for enterprise readiness remediation contracts.
#
# Enforces key report remediations so "green" cannot silently regress:
# - enterprise health-check port truth (catalog=8160, license-manager=18170)
# - no unrelated purchase-gateway mappings in enterprise/domain/migration testmaps
# - migration verification pipeline includes required argumentized jobs
# - enterprise verification scripts retain readiness/port hardening
# - canonical runbook testmap naming remains .testmap.yml
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

assert_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if rg -n --pcre2 -- "$pattern" "$file" >/dev/null 2>&1; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if rg -n --pcre2 -- "$pattern" "$file" >/dev/null 2>&1; then
    fail "$msg"
  else
    pass "$msg"
  fi
}

SPEC_FILE="specs/enterprise-microservices_spec.md"
TESTMAP_FILE="specs/testmaps/enterprise-microservices_spec.testmap.yml"
DOMAIN_TESTMAP="specs/testmaps/multi-site-domains_spec.testmap.yml"
MIGRATION_TESTMAP="specs/testmaps/data-migrations-kajabi-mct_spec.testmap.yml"
PIPELINE="scripts/migrations/run-verification-pipeline.sh"
SERVICE_DEPLOY="scripts/qa/verify-enterprise-service-deployment.sh"
LICENSE_MGMT="scripts/qa/verify-enterprise-license-management.sh"
RUNBOOK_TENANT="docs/runbooks/tenant-provisioning-runbook.md"
RUNBOOK_ENTERPRISE="docs/runbooks/enterprise-services-runbook.md"
ONBOARD_SCRIPT="scripts/tenants/onboard-enterprise-tenant.sh"
RELEASE_SCRIPT="scripts/infra/release-openedx-gitops.sh"

# 1) Port truth (AC-003 contract alignment)
assert_contains "$SPEC_FILE" 'AC-003:.*enterprise-catalog:8160/health/' \
  "enterprise spec AC-003 uses enterprise-catalog:8160"
assert_not_contains "$SPEC_FILE" 'AC-003:.*enterprise-catalog:8000/health/' \
  "enterprise spec AC-003 no longer references enterprise-catalog:8000"
assert_contains "$TESTMAP_FILE" '^- id: AC-003$' \
  "enterprise testmap contains AC-003 entry"
assert_contains "$TESTMAP_FILE" 'enterprise-catalog:8160/health/' \
  "enterprise testmap uses enterprise-catalog:8160"
assert_not_contains "$TESTMAP_FILE" 'enterprise-catalog:8000/health/' \
  "enterprise testmap no longer references enterprise-catalog:8000"

# 2) No stale purchase-gateway contamination in targeted testmaps
for f in "$TESTMAP_FILE" "$DOMAIN_TESTMAP" "$MIGRATION_TESTMAP"; do
  assert_not_contains "$f" '(purchase-gateway|services/purchase-gateway|verify-purchase-gateway)' \
    "$(basename "$f") has no unrelated purchase-gateway mappings"
done

# 3) Migration verification orchestrator required argumentized jobs
assert_contains "$PIPELINE" '"verify-user-import-counts.sh --source kajabi"' \
  "pipeline includes user-import verification for Kajabi"
assert_contains "$PIPELINE" '"verify-user-import-counts.sh --source mct"' \
  "pipeline includes user-import verification for MCT"
assert_contains "$PIPELINE" '"verify-course-import-counts.sh --source kajabi"' \
  "pipeline includes course-import verification for Kajabi"
assert_contains "$PIPELINE" '"verify-course-import-counts.sh --source mct"' \
  "pipeline includes course-import verification for MCT"
assert_contains "$PIPELINE" '"verify-enrollment-import-counts.sh --source kajabi"' \
  "pipeline includes enrollment-import verification for Kajabi"
assert_contains "$PIPELINE" '"verify-enrollment-import-counts.sh --source mct"' \
  "pipeline includes enrollment-import verification for MCT"

# 4) Enterprise QA hardening remains in place
assert_contains "$SERVICE_DEPLOY" 'ALLOW_PARTIAL_READY=' \
  "enterprise service deployment checker retains partial-readiness compatibility flag"
assert_contains "$SERVICE_DEPLOY" 'WAIT_FOR_STEADY_SECONDS=' \
  "enterprise service deployment checker retains steady-state wait control"
assert_contains "$SERVICE_DEPLOY" 'localhost:18170/health/' \
  "enterprise service deployment checker probes license-manager on 18170"
assert_contains "$LICENSE_MGMT" 'LM_PORT=18170' \
  "license-management checker uses LM_PORT=18170"

# 5) Migration edge-shape handling remains guarded
assert_contains 'scripts/qa/verify-kajabi-transform.sh' 'openedx/users_import.csv' \
  "Kajabi transform verifier checks canonical openedx users CSV path"
assert_contains 'scripts/qa/verify-mct-export.sh' 'check_categories_shape\(\)' \
  "MCT export verifier handles nested category envelope shape"
assert_contains 'scripts/qa/verify-mux-video-upload.sh' 'has\("total_videos"\)' \
  "Mux upload verifier handles summary-object format"
assert_contains 'scripts/qa/verify-kajabi-olx-packages.sh' 'find "\$PACKAGE_DIR" -type f -name "\*\.tar\.gz"' \
  "Kajabi OLX verifier safely discovers tarballs via find"
assert_not_contains 'scripts/qa/verify-cross-system-identity.sh' 'sort\s*\|\s*head' \
  "Cross-system identity verifier avoids pipefail-prone sort|head pattern"

# 6) Runbooks keep canonical testmap references
assert_contains "$RUNBOOK_TENANT" 'specs/testmaps/multi-tenancy-architecture_spec.testmap.yml' \
  "tenant provisioning runbook references canonical .testmap.yml path"
assert_contains "$RUNBOOK_ENTERPRISE" 'specs/testmaps/enterprise-microservices_spec.testmap.yml' \
  "enterprise services runbook references canonical .testmap.yml path"
assert_not_contains "$RUNBOOK_TENANT" '_testmap\.ya?ml' \
  "tenant provisioning runbook has no legacy _testmap.yaml reference"
assert_not_contains "$RUNBOOK_ENTERPRISE" '_testmap\.ya?ml' \
  "enterprise services runbook has no legacy _testmap.yaml reference"

# 7) Deterministic enterprise onboarding workflow contract
assert_contains "$ONBOARD_SCRIPT" '\[1/6\] Provision/reconcile tenant' \
  "onboarding workflow includes step 1/6 tenant provisioning"
assert_contains "$ONBOARD_SCRIPT" '\[2/6\] Sync SiteConfiguration ENTERPRISE_CUSTOMER_UUID mapping' \
  "onboarding workflow includes step 2/6 enterprise-site mapping sync"
assert_contains "$ONBOARD_SCRIPT" '\[3/6\] Configure tenant IdP' \
  "onboarding workflow includes step 3/6 tenant IdP configuration"
assert_contains "$ONBOARD_SCRIPT" '\[4/6\] Sync tenant branding scaffold' \
  "onboarding workflow includes step 4/6 branding scaffold sync"
assert_contains "$ONBOARD_SCRIPT" '\[5/6\] Run migration verification pipeline' \
  "onboarding workflow includes step 5/6 migration verification"
assert_contains "$ONBOARD_SCRIPT" '\[6/6\] Run runtime readiness gates' \
  "onboarding workflow includes step 6/6 runtime readiness gates"
assert_contains "$ONBOARD_SCRIPT" 'run-verification-pipeline\.sh' \
  "onboarding workflow invokes migration verification pipeline"
assert_contains "$ONBOARD_SCRIPT" 'verify-enterprise-sso-readiness\.sh' \
  "onboarding workflow invokes enterprise SSO readiness gate"
assert_contains "$ONBOARD_SCRIPT" 'STRICT=1 REQUIRE_ENTERPRISE_SITE_MAPPING=1' \
  "onboarding workflow enforces strict enterprise site mapping in prod runtime gate"

# 8) Production release orchestration guard contract
assert_contains "$RELEASE_SCRIPT" 'RUN_ENTERPRISE_SSO_RUNTIME_GUARD=' \
  "release workflow exposes enterprise SSO runtime guard toggle"
assert_contains "$RELEASE_SCRIPT" '--skip-enterprise-sso-runtime-guard' \
  "release workflow supports explicit skip flag for enterprise SSO runtime guard"
assert_contains "$RELEASE_SCRIPT" '--enterprise-readiness-tenant' \
  "release workflow supports tenant override for enterprise readiness"
assert_contains "$RELEASE_SCRIPT" 'verify-enterprise-sso-readiness\.sh' \
  "release workflow invokes enterprise SSO readiness check in production preflight"

echo
if [[ "$failures" -eq 0 ]]; then
  echo "✓ Enterprise readiness integrity checks passed"
  exit 0
else
  echo "✗ $failures enterprise readiness integrity check(s) failed"
  exit 1
fi
