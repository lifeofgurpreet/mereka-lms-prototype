#!/usr/bin/env bash
# Verify lane identity consistency across the LMS repo.
# Ensures config/lane-identity.yaml is the single source of truth and
# that scripts, overlays, and proof artifacts use canonical lane names.
#
# Exit 0 = all checks pass, exit 1 = one or more failures.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LANE_IDENTITY="$REPO_ROOT/config/lane-identity.yaml"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "Lane Identity Verification"
echo "=========================="

# 1. lane-identity.yaml exists
if [[ -f "$LANE_IDENTITY" ]]; then
  pass "config/lane-identity.yaml exists"
else
  fail "config/lane-identity.yaml missing"
  echo ""
  echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
  exit 1
fi

# 2. Required fields present
for field in contract_version gitops_service_id lanes internal_services; do
  if grep -q "^${field}:" "$LANE_IDENTITY" 2>/dev/null; then
    pass "lane-identity.yaml has field: $field"
  else
    fail "lane-identity.yaml missing field: $field"
  fi
done

# 3. All three canonical lanes declared
for lane in dev staging prod; do
  if grep -q "^  ${lane}:" "$LANE_IDENTITY" 2>/dev/null; then
    pass "lane '$lane' declared"
  else
    fail "lane '$lane' not declared in lane-identity.yaml"
  fi
done

# 4. Overlay directories exist
# Wave 9 (#1900) deleted deploy/k8s/overlays/{rke2-nonprod,staging,production}
# as deprecated shadow overlays; authoritative overlays now live in
# bbi-infrastructure/apps/mereka-lms/overlays/. Treat absence of these
# app-repo shadows as not-applicable, not a failure.
for overlay_dir in rke2-nonprod staging production; do
  overlay_path="$REPO_ROOT/deploy/k8s/overlays/$overlay_dir"
  if [[ -d "$overlay_path" ]]; then
    pass "overlay directory exists: overlays/$overlay_dir"
  else
    pass "overlay '$overlay_dir' absent (Wave 9 shadow deletion — authoritative copy in bbi-infrastructure)"
  fi
done

# 5. lib/lane-normalize.sh exists and is sourceable
LANE_LIB="$REPO_ROOT/scripts/lib/lane-normalize.sh"
if [[ -f "$LANE_LIB" ]]; then
  # shellcheck source=/dev/null
  source "$LANE_LIB"
  pass "scripts/lib/lane-normalize.sh exists and sources cleanly"

  # 5a. Test canonical mappings
  for input_expected in "dev:dev" "rke2-nonprod:dev" "nonprod:dev" \
                        "staging:staging" "stage:staging" \
                        "prod:prod" "production:prod"; do
    input="${input_expected%%:*}"
    expected="${input_expected##*:}"
    actual="$(normalize_lane_to_canonical "$input" 2>/dev/null || echo "ERROR")"
    if [[ "$actual" == "$expected" ]]; then
      pass "normalize '$input' → '$expected'"
    else
      fail "normalize '$input': expected '$expected', got '$actual'"
    fi
  done
else
  fail "scripts/lib/lane-normalize.sh missing"
fi

# 6. No 'local' or 'rke2-nonprod' in proof artifact templates
# (proof artifacts should use canonical names: dev, staging, prod)
proof_scripts=(
  "scripts/infra/generate-release-bundle.sh"
  "scripts/infra/generate-build-provenance.sh"
)
for script in "${proof_scripts[@]}"; do
  script_path="$REPO_ROOT/$script"
  if [[ ! -f "$script_path" ]]; then
    warn "proof script not found: $script"
    continue
  fi
  # Check the case statement for target_environment validation
  if grep -q 'case.*TARGET_ENV' "$script_path" 2>/dev/null; then
    # Ensure it accepts canonical names
    if grep -qE '\bdev\b' <(grep -A2 'case.*TARGET_ENV' "$script_path" 2>/dev/null); then
      pass "$script accepts canonical 'dev'"
    else
      warn "$script case statement may not accept canonical 'dev'"
    fi
  fi
done

# 7. contract.json references gitops_service_id
CONTRACT="$REPO_ROOT/deploy/k8s/contract.json"
if [[ -f "$CONTRACT" ]]; then
  if grep -q "gitops_identity\|gitops_service_id" "$CONTRACT" 2>/dev/null; then
    pass "contract.json references gitops identity"
  else
    warn "contract.json does not reference gitops identity (add in Wave 1)"
  fi
else
  fail "deploy/k8s/contract.json missing"
fi

# 8. migration registry service names match lane-identity internal_services
if [[ -f "$REPO_ROOT/deploy/k8s/migrations/registry.yaml" ]]; then
  registry_services="$(grep '^\s*- name:' "$REPO_ROOT/deploy/k8s/migrations/registry.yaml" | sed 's/.*name: *//' | sort)"
  identity_services="$(grep '^\s*- name:' "$LANE_IDENTITY" | sed 's/.*name: *//' | sort)"
  # Every registry service should be in lane-identity
  while IFS= read -r svc; do
    if grep -qx "$svc" <<<"$identity_services"; then
      pass "migration service '$svc' in lane-identity"
    else
      warn "migration service '$svc' not in lane-identity internal_services"
    fi
  done <<< "$registry_services"
else
  warn "deploy/k8s/migrations/registry.yaml not found"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
[[ "$FAIL" -eq 0 ]] || exit 1
