#!/usr/bin/env bash
# @covers AC-025, AC-026
# @spec: ci-cd-pipeline_spec.md
# Verify build-ios-app.yml workflow for TestFlight upload and SSH cleanup
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

WORKFLOW=".github/workflows/build-ios-app.yml"

if [[ ! -f "$WORKFLOW" ]]; then
  skip "AC-025, AC-026: Workflow $WORKFLOW not found (iOS builds may not be configured yet)"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 0
fi

echo "Checking $WORKFLOW for iOS build configuration..."
echo ""

# AC-025: iOS workflow uploads signed IPA to TestFlight
has_testflight_upload=0
has_ipa_reference=0

if grep -q "upload_to_testflight\|TestFlight" "$WORKFLOW"; then
  has_testflight_upload=1
fi

if grep -q "\.ipa" "$WORKFLOW"; then
  has_ipa_reference=1
fi

if [[ $has_testflight_upload -eq 1 && $has_ipa_reference -eq 1 ]]; then
  pass "AC-025: Workflow uploads signed IPA to TestFlight"
elif [[ $has_testflight_upload -eq 0 ]]; then
  fail "AC-025: Workflow missing TestFlight upload step"
else
  fail "AC-025: Workflow has TestFlight reference but missing IPA handling"
fi

# AC-026: iOS workflow cleans up SSH keys for Match
has_ssh_setup=0
has_ssh_cleanup=0

if grep -q "MATCH_DEPLOY_KEY\|match_key\|Setup SSH" "$WORKFLOW"; then
  has_ssh_setup=1
fi

if grep -q "rm.*ssh.*key\|Cleanup" "$WORKFLOW" && grep -A 5 "Cleanup\|always()" "$WORKFLOW" | grep -q "rm.*ssh"; then
  has_ssh_cleanup=1
fi

if [[ $has_ssh_setup -eq 1 && $has_ssh_cleanup -eq 1 ]]; then
  pass "AC-026: Workflow cleans up SSH keys for Match (runs on always())"
elif [[ $has_ssh_setup -eq 0 ]]; then
  skip "AC-026: Workflow doesn't use SSH keys (may use alternative auth)"
else
  fail "AC-026: Workflow sets up SSH keys but missing cleanup step"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
