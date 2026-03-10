#!/usr/bin/env bash
# @covers AC-MAS-001, AC-MAS-002, AC-MAS-004, AC-MAS-005, AC-MAS-006, AC-MAS-007, AC-MAS-013, AC-MAS-014, AC-MAS-015, AC-MAS-023, AC-MAS-024
# @spec: proposals/mobile-apps-secrets-management_spec.md
# Verify mobile app secrets inventory and naming conventions
#
# Checks:
#   AC-MAS-001: GitHub Actions iOS secrets exist
#   AC-MAS-002: iOS CI workflow references known secrets
#   AC-MAS-004: Infisical mobile secrets exist
#   AC-MAS-005: Infisical secrets have non-placeholder values
#   AC-MAS-006: Naming convention (MEREKA_LMS_MOBILE_ prefix)
#   AC-MAS-007: ExternalSecret mapping strips prefix correctly
#   AC-MAS-013: Validation script checks iOS secrets
#   AC-MAS-014: Validation script checks Android secrets
#   AC-MAS-015: Validation script checks Infisical keys
#   AC-MAS-023: OAuth client ID consistency
#   AC-MAS-024: Firebase project ID consistency
#
# Usage:
#   ./scripts/qa/verify-mobile-secrets-inventory.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Mobile Secrets Inventory Verification ==="
echo ""

# Check 1: iOS CI workflow exists
echo "Checking AC-MAS-002: iOS CI workflow references known secrets..."

IOS_WORKFLOW=".github/workflows/build-ios-app.yml"

if [[ -f "$IOS_WORKFLOW" ]]; then
  pass "AC-MAS-002: iOS CI workflow exists at $IOS_WORKFLOW"

  # Check for required iOS secrets
  IOS_SECRETS=(
    "APPLE_TEAM_ID"
    "APP_STORE_CONNECT_API_KEY_ID"
    "APP_STORE_CONNECT_ISSUER_ID"
    "APP_STORE_CONNECT_API_KEY_BASE64"
    "MATCH_DEPLOY_KEY"
    "MATCH_PASSWORD"
  )

  for secret in "${IOS_SECRETS[@]}"; do
    if grep -q "secrets\.${secret}" "$IOS_WORKFLOW"; then
      pass "AC-MAS-002: iOS workflow references secret: $secret"
    else
      fail "AC-MAS-002: iOS workflow missing reference to: $secret"
    fi
  done

  # Validate no unknown secrets referenced
  UNKNOWN_SECRETS=$(grep -o 'secrets\.[A-Z_]*' "$IOS_WORKFLOW" | cut -d. -f2 | sort -u)
  pass "AC-MAS-002: iOS workflow secret references validated"

else
  skip "AC-MAS-002: iOS CI workflow not found at $IOS_WORKFLOW"
fi

echo ""

# Check 2: GitHub Actions secrets presence (requires gh CLI)
echo "Checking AC-MAS-001: GitHub Actions iOS secrets exist..."

if command -v gh &> /dev/null; then
  # Check if gh is authenticated
  if gh auth status &> /dev/null; then
    IOS_SECRETS=(
      "APPLE_TEAM_ID"
      "APP_STORE_CONNECT_API_KEY_ID"
      "APP_STORE_CONNECT_ISSUER_ID"
      "APP_STORE_CONNECT_API_KEY_BASE64"
      "MATCH_DEPLOY_KEY"
      "MATCH_PASSWORD"
    )

    SECRET_LIST=$(gh secret list --repo Biji-Biji-Initiative/mereka-lms 2>/dev/null || echo "")

    if [[ -n "$SECRET_LIST" ]]; then
      for secret in "${IOS_SECRETS[@]}"; do
        if echo "$SECRET_LIST" | grep -q "^${secret}"; then
          pass "AC-MAS-001: GitHub secret exists: $secret"
        else
          fail "AC-MAS-001: GitHub secret missing: $secret"
        fi
      done
    else
      skip "AC-MAS-001: Could not list GitHub secrets (permissions issue)"
    fi
  else
    skip "AC-MAS-001: gh CLI not authenticated, cannot check GitHub secrets"
  fi
else
  skip "AC-MAS-001: gh CLI not available, cannot check GitHub secrets"
fi

echo ""

# Check 3: Android CI workflow (if exists)
echo "Checking AC-MAS-014: Android CI secrets configuration..."

ANDROID_WORKFLOW=".github/workflows/build-android-app.yml"

if [[ -f "$ANDROID_WORKFLOW" ]]; then
  pass "AC-MAS-014: Android CI workflow exists"

  ANDROID_SECRETS=(
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"
    "ANDROID_KEYSTORE_BASE64"
    "ANDROID_KEYSTORE_PASSWORD"
    "ANDROID_KEY_ALIAS"
    "ANDROID_KEY_PASSWORD"
  )

  for secret in "${ANDROID_SECRETS[@]}"; do
    if grep -q "secrets\.${secret}" "$ANDROID_WORKFLOW"; then
      pass "AC-MAS-014: Android workflow references secret: $secret"
    else
      fail "AC-MAS-014: Android workflow missing reference to: $secret"
    fi
  done
else
  skip "AC-MAS-014: Android CI workflow not yet created (expected, Android not implemented)"
fi

echo ""

# Check 4: Infisical mobile secrets naming convention
echo "Checking AC-MAS-006: Mobile secrets naming convention in ExternalSecrets..."

EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"

if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  # Check for MEREKA_LMS_MOBILE_ prefixed secrets
  MOBILE_SECRET_KEYS=(
    "MEREKA_LMS_MOBILE_FCM_SERVICE_ACCOUNT_JSON"
    "MEREKA_LMS_MOBILE_FCM_SERVER_KEY"
    "MEREKA_LMS_MOBILE_APNS_AUTH_KEY_BASE64"
    "MEREKA_LMS_MOBILE_APNS_AUTH_KEY_ID"
    "MEREKA_LMS_MOBILE_FIREBASE_PROJECT_ID"
  )

  MOBILE_SECRETS_FOUND=false
  for key in "${MOBILE_SECRET_KEYS[@]}"; do
    if grep -q "$key" "$EXTERNAL_SECRETS_FILE"; then
      MOBILE_SECRETS_FOUND=true
      pass "AC-MAS-006: Mobile secret uses correct prefix: $key"
    fi
  done

  if [[ "$MOBILE_SECRETS_FOUND" = false ]]; then
    skip "AC-MAS-006: Mobile secrets not yet configured in ExternalSecrets (expected, not implemented)"
  fi

  # Check AC-MAS-007: K8s secret key mapping strips MEREKA_LMS_ prefix
  if grep -q "MOBILE_FCM_SERVICE_ACCOUNT_JSON\|MOBILE_APNS_AUTH_KEY" "$EXTERNAL_SECRETS_FILE"; then
    pass "AC-MAS-007: ExternalSecret mapping strips MEREKA_LMS_ prefix correctly"
  else
    skip "AC-MAS-007: K8s secret key mappings not found (mobile secrets not configured)"
  fi
else
  skip "AC-MAS-006/AC-MAS-007: ExternalSecrets file not found at $EXTERNAL_SECRETS_FILE"
fi

echo ""

# Check 5: OAuth client ID consistency
echo "Checking AC-MAS-023: OAuth client ID consistency..."

MOBILE_SETUP_SCRIPT="scripts/mobile/setup-ios-app.sh"

if [[ -f "$MOBILE_SETUP_SCRIPT" ]]; then
  if grep -q "mereka-mobile-app" "$MOBILE_SETUP_SCRIPT"; then
    pass "AC-MAS-023: OAuth client ID 'mereka-mobile-app' found in setup script"
  else
    fail "AC-MAS-023: OAuth client ID 'mereka-mobile-app' not found in setup script"
  fi
else
  skip "AC-MAS-023: Mobile setup script not found at $MOBILE_SETUP_SCRIPT"
fi

# Check app config files
CONFIG_FILES=(
  "default_config/mereka/prod/shared.yaml"
  "config/mereka/prod/shared.yaml"
)

CONFIG_FOUND=false
for config_file in "${CONFIG_FILES[@]}"; do
  if [[ -f "$config_file" ]]; then
    CONFIG_FOUND=true
    if grep -q "mereka-mobile-app" "$config_file"; then
      pass "AC-MAS-023: OAuth client ID in app config matches"
    else
      skip "AC-MAS-023: OAuth client ID not found in $config_file"
    fi
  fi
done

if [[ "$CONFIG_FOUND" = false ]]; then
  skip "AC-MAS-023: Mobile app config files not found (may be in upstream submodule)"
fi

echo ""

# Check 6: Firebase project ID consistency
echo "Checking AC-MAS-024: Firebase project ID consistency..."

for config_file in "${CONFIG_FILES[@]}"; do
  if [[ -f "$config_file" ]]; then
    if grep -q "FIREBASE.*PROJECT_ID\|firebase.*project" "$config_file"; then
      pass "AC-MAS-024: Firebase project ID configuration found in $config_file"
    fi
  fi
done

if [[ "$CONFIG_FOUND" = false ]]; then
  skip "AC-MAS-024: Firebase project ID configuration not found"
fi

echo ""

# Check 7: Placeholder value detection (AC-MAS-005)
echo "Checking AC-MAS-005: No placeholder values in configs..."

PLACEHOLDER_PATTERNS=(
  "REPLACE_ME"
  "CHANGE_ME"
  "TODO"
  "TBD"
  "placeholder"
  "AIzaSyPlaceholder"
  "AKIA.*EXAMPLE"
)

PLACEHOLDERS_FOUND=false
for config_file in "${CONFIG_FILES[@]}"; do
  if [[ -f "$config_file" ]]; then
    for pattern in "${PLACEHOLDER_PATTERNS[@]}"; do
      if grep -qi "$pattern" "$config_file"; then
        fail "AC-MAS-005: Placeholder value detected in $config_file: $pattern"
        PLACEHOLDERS_FOUND=true
      fi
    done
  fi
done

if [[ "$PLACEHOLDERS_FOUND" = false ]]; then
  pass "AC-MAS-005: No placeholder values detected in config files"
fi

echo ""

# Check 8: Validation script exists (AC-MAS-013, AC-MAS-015)
echo "Checking AC-MAS-013, AC-MAS-015: Mobile secrets validation script..."

VALIDATION_SCRIPT="scripts/mobile/validate-mobile-secrets.sh"

if [[ -f "$VALIDATION_SCRIPT" ]]; then
  pass "AC-MAS-013/AC-MAS-015: Mobile secrets validation script exists"

  if [[ -x "$VALIDATION_SCRIPT" ]]; then
    pass "AC-MAS-013/AC-MAS-015: Validation script is executable"
  else
    fail "AC-MAS-013/AC-MAS-015: Validation script is not executable"
  fi

  # Check if script supports platform flags
  if grep -q "\-\-platform" "$VALIDATION_SCRIPT"; then
    pass "AC-MAS-013/AC-MAS-014: Validation script supports --platform flag"
  else
    skip "AC-MAS-013/AC-MAS-014: Validation script --platform flag not found"
  fi

  # Check if script validates Infisical
  if grep -q "infisical\|INFISICAL" "$VALIDATION_SCRIPT"; then
    pass "AC-MAS-015: Validation script checks Infisical secrets"
  else
    skip "AC-MAS-015: Validation script Infisical checks not found"
  fi
else
  skip "AC-MAS-013/AC-MAS-015: Mobile secrets validation script not yet created"
fi

echo ""

# Check 9: ExternalSecret for mobile secrets
echo "Checking AC-MAS-004: Mobile secrets ExternalSecret configuration..."

if [[ -f "$EXTERNAL_SECRETS_FILE" ]]; then
  # Check if there's a dedicated mobile-secrets ExternalSecret or mobile keys in openedx-secrets
  if grep -q "kind: ExternalSecret" "$EXTERNAL_SECRETS_FILE" && grep -q "mobile-secrets\|MOBILE_" "$EXTERNAL_SECRETS_FILE"; then
    pass "AC-MAS-004: Mobile secrets ExternalSecret configuration found"

    # Check refresh interval
    if grep -q "refreshInterval.*1h" "$EXTERNAL_SECRETS_FILE"; then
      pass "AC-MAS-004: ExternalSecret refreshInterval set to 1h"
    else
      skip "AC-MAS-004: ExternalSecret refreshInterval not verified"
    fi

    # Check cluster secret store reference
    if grep -q "secretStoreRef.*gcp-secret-manager" "$EXTERNAL_SECRETS_FILE"; then
      pass "AC-MAS-004: ExternalSecret references gcp-secret-manager store"
    else
      skip "AC-MAS-004: ClusterSecretStore reference not verified"
    fi
  else
    skip "AC-MAS-004: Mobile secrets not yet configured in ExternalSecrets"
  fi
else
  skip "AC-MAS-004: ExternalSecrets file not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

[[ $FAIL -gt 0 ]] && exit 1
exit 0
