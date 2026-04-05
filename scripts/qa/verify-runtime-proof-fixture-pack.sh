#!/usr/bin/env bash
# @covers AC-MTA-001
# @spec: multi-tenancy-architecture_spec.md
#
# verify-runtime-proof-fixture-pack.sh — CI-safe static verifier for the
# synthetic runtime proof fixture pack.
#
# Checks that all required files exist, the manifest is valid YAML, the
# bootstrap and validate tools are present and executable, and that key
# safety invariants are present in the manifest.
#
# Does NOT connect to a live cluster. Safe to run in any CI environment.
#
# Usage:
#   bash scripts/qa/verify-runtime-proof-fixture-pack.sh
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────
_pass() {
  echo "  [PASS] $1"
  PASS=$(( PASS + 1 ))
}

_fail() {
  echo "  [FAIL] $1"
  FAIL=$(( FAIL + 1 ))
}

_check_file_exists() {
  local label="$1"
  local path="$2"
  if [[ -f "${REPO_ROOT}/${path}" ]]; then
    _pass "${label}: ${path} exists"
  else
    _fail "${label}: ${path} NOT FOUND"
  fi
}

_check_executable() {
  local label="$1"
  local path="$2"
  if [[ -x "${REPO_ROOT}/${path}" ]]; then
    _pass "${label}: ${path} is executable"
  else
    _fail "${label}: ${path} is NOT executable (chmod +x required)"
  fi
}

_yaml_valid() {
  local label="$1"
  local path="$2"
  # Use python3 yaml parsing — available in CI without extra deps.
  if python3 -c "
import sys, yaml
try:
    yaml.safe_load(open('${REPO_ROOT}/${path}', encoding='utf-8'))
    sys.exit(0)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
    _pass "${label}: ${path} is valid YAML"
  else
    _fail "${label}: ${path} failed YAML parse"
  fi
}

_manifest_contains() {
  local label="$1"
  local path="$2"
  local python_expr="$3"
  if python3 -c "
import sys, yaml
m = yaml.safe_load(open('${REPO_ROOT}/${path}', encoding='utf-8'))
result = (${python_expr})
sys.exit(0 if result else 1)
" 2>/dev/null; then
    _pass "${label}"
  else
    _fail "${label}"
  fi
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "========================================================================"
echo "Synthetic Runtime Proof Fixture Pack — Static Verifier"
echo "Repo root: ${REPO_ROOT}"
echo "========================================================================"
echo ""

declare -A MANIFESTS=(
  [dev]="config/runtime-proof/dev.synthetic-proof-fixtures.yaml"
  [staging]="config/runtime-proof/staging.synthetic-proof-fixtures.yaml"
  [production]="config/runtime-proof/prod.synthetic-proof-fixtures.yaml"
)

# ── Section 1: Core documents ─────────────────────────────────────────────────
echo "--- Section 1: Core documents ---"
_check_file_exists \
  "contract_doc" \
  "docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md"

_check_file_exists \
  "smoke_account_registry_contract" \
  "config/smoke-account-registry.yaml"

for env in dev staging production; do
  _check_file_exists \
    "manifest:${env}" \
    "${MANIFESTS[$env]}"
done

_check_file_exists \
  "execution_packet" \
  "docs/reviews/RUNTIME_PROOF_FIXTURE_EXECUTION_PACKET.md"

_check_file_exists \
  "rollback_packet" \
  "docs/reviews/RUNTIME_PROOF_FIXTURE_ROLLBACK_PACKET.md"

_check_file_exists \
  "handoff_doc" \
  "docs/reviews/RUNTIME_PROOF_FIXTURE_HANDOFF.md"

echo ""

# ── Section 2: Tooling ────────────────────────────────────────────────────────
echo "--- Section 2: Tooling ---"
_check_file_exists \
  "bootstrap_tool" \
  "scripts/tenants/bootstrap-runtime-proof-fixtures.py"

_check_file_exists \
  "validate_tool" \
  "scripts/tenants/validate-runtime-proof-fixtures.py"

_check_file_exists \
  "shared_library" \
  "scripts/tenants/lib/proof_fixtures.py"

_check_file_exists \
  "shared_library_init" \
  "scripts/tenants/lib/__init__.py"

_check_file_exists \
  "catalog_companion_tool" \
  "scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py"

_check_executable \
  "bootstrap_tool_executable" \
  "scripts/tenants/bootstrap-runtime-proof-fixtures.py"

_check_executable \
  "validate_tool_executable" \
  "scripts/tenants/validate-runtime-proof-fixtures.py"

_check_executable \
  "catalog_companion_tool_executable" \
  "scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py"

echo ""

# ── Section 3: Manifest YAML validity ─────────────────────────────────────────
echo "--- Section 3: Manifest YAML validity ---"
for env in dev staging production; do
  _yaml_valid "manifest_yaml:${env}" "${MANIFESTS[$env]}"
done

echo ""

# ── Section 4: Required fixture classes in manifest ───────────────────────────
echo "--- Section 4: Required fixture classes ---"
for env in dev staging production; do
  _manifest_contains \
    "fixture_class:${env}:synthetic_identities" \
    "${MANIFESTS[$env]}" \
    "'synthetic_identities' in m.get('fixture_classes', {})"

  _manifest_contains \
    "fixture_class:${env}:lms_enterprise_data" \
    "${MANIFESTS[$env]}" \
    "'lms_enterprise_data' in m.get('fixture_classes', {})"

  _manifest_contains \
    "fixture_class:${env}:enterprise_catalog_service_data" \
    "${MANIFESTS[$env]}" \
    "'enterprise_catalog_service_data' in m.get('fixture_classes', {})"

  _manifest_contains \
    "fixture_class:${env}:waffle_flags" \
    "${MANIFESTS[$env]}" \
    "'waffle_flags' in m.get('fixture_classes', {})"
done

echo ""

# ── Section 5: Safety invariant ───────────────────────────────────────────────
echo "--- Section 5: Safety invariant ---"
for env in dev staging production; do
  _manifest_contains \
    "real_account_mutation_forbidden:${env}:true" \
    "${MANIFESTS[$env]}" \
    "m.get('real_account_mutation_forbidden') is True"
done

echo ""

# ── Section 6: LMS + enterprise-catalog split ─────────────────────────────────
echo "--- Section 6: LMS + enterprise-catalog catalog split ---"
for env in dev staging production; do
  _manifest_contains \
    "lms_enterprise_data:${env}:has_catalogs" \
    "${MANIFESTS[$env]}" \
    "any(
      ec.get('catalogs')
      for ec in m.get('fixture_classes', {})
                 .get('lms_enterprise_data', {})
                 .get('enterprise_customers', [])
    )"

  _manifest_contains \
    "enterprise_catalog_service_data:${env}:has_catalogs" \
    "${MANIFESTS[$env]}" \
    "bool(
      m.get('fixture_classes', {})
       .get('enterprise_catalog_service_data', {})
       .get('catalogs')
    )"
done

echo ""

# ── Section 7: Python validate tool exit code ─────────────────────────────────
echo "--- Section 7: validate tool runs clean ---"
for env in dev staging production; do
  if python3 "${REPO_ROOT}/scripts/tenants/validate-runtime-proof-fixtures.py" \
      --env "$env" --json > /dev/null 2>&1; then
    _pass "validate_tool:${env}:exit_code_0"
  else
    _fail "validate_tool:${env}:non_zero_exit"
  fi
done

echo ""

# ── Section 8: Bootstrap dry-run exit code ────────────────────────────────────
echo "--- Section 8: bootstrap dry-run runs clean ---"
for env in dev staging production; do
  if python3 "${REPO_ROOT}/scripts/tenants/bootstrap-runtime-proof-fixtures.py" \
      --env "$env" --json > /dev/null 2>&1; then
    _pass "bootstrap_tool:${env}:dry_run_exit_code_0"
  else
    _fail "bootstrap_tool:${env}:dry_run_non_zero_exit"
  fi
done

echo ""

# ── Section 9: Catalog companion dry-run ──────────────────────────────────────
echo "--- Section 9: catalog companion dry-run runs clean ---"
for env in dev staging production; do
  if python3 "${REPO_ROOT}/scripts/tenants/bootstrap-runtime-proof-fixtures-catalog.py" \
      --env "$env" --json > /dev/null 2>&1; then
    _pass "catalog_companion_tool:${env}:dry_run_exit_code_0"
  else
    _fail "catalog_companion_tool:${env}:dry_run_non_zero_exit"
  fi
done

echo ""

# ── Section 10: Enterprise link authoritative source ──────────────────────────
echo "--- Section 10: enterprise_link is the single authoritative source ---"
for env in dev staging production; do
  _manifest_contains \
    "enterprise_link:${env}:no_user_links_key" \
    "${MANIFESTS[$env]}" \
    "not any(
      'user_links' in (user if isinstance(user, dict) else {})
      for user in
        m.get('fixture_classes', {})
         .get('synthetic_identities', {})
         .get('users', [])
    )"

  _manifest_contains \
    "enterprise_link:${env}:present_in_at_least_one_user" \
    "${MANIFESTS[$env]}" \
    "any(
      'enterprise_link' in (user if isinstance(user, dict) else {})
      for user in
        m.get('fixture_classes', {})
         .get('synthetic_identities', {})
         .get('users', [])
    )"
done

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "========================================================================"
echo "Results: ${PASS} passed, ${FAIL} failed"
echo "========================================================================"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo "VERDICT: FAIL — ${FAIL} check(s) did not pass."
  exit 1
else
  echo "VERDICT: PASS — all checks passed."
  exit 0
fi
