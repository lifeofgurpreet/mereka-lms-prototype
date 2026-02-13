#!/usr/bin/env bash
# @covers AC-021
# @spec: ci-cd-pipeline_spec.md
# Verify release-openedx-gitops.sh supports rollback without building new images
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

SCRIPT="scripts/infra/release-openedx-gitops.sh"

if [[ ! -f "$SCRIPT" ]]; then
  fail "AC-021: Script $SCRIPT not found"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 1
fi

echo "Verifying $SCRIPT supports rollback without image builds..."
echo ""

# Check script is executable
if [[ ! -x "$SCRIPT" ]]; then
  fail "AC-021: $SCRIPT not executable"
else
  pass "AC-021: Script is executable"
fi

# Verify script accepts tag parameters
has_openedx_tag=0
has_mfe_tag=0

if grep -q "openedx-tag\|OPENEDX_TAG" "$SCRIPT"; then
  has_openedx_tag=1
fi

if grep -q "mfe-tag\|MFE_TAG" "$SCRIPT"; then
  has_mfe_tag=1
fi

if [[ $has_openedx_tag -eq 1 && $has_mfe_tag -eq 1 ]]; then
  pass "AC-021: Script accepts tag parameters (openedx-tag, mfe-tag)"
else
  fail "AC-021: Script missing tag parameter support"
fi

# Verify script does NOT trigger image builds
has_no_build_openedx=0
has_no_docker_build=0

if ! grep -q "tutor images build openedx\|tutor.*build.*openedx" "$SCRIPT"; then
  has_no_build_openedx=1
fi

if ! grep -q "docker build\|docker buildx build" "$SCRIPT"; then
  has_no_docker_build=1
fi

if [[ $has_no_build_openedx -eq 1 && $has_no_docker_build -eq 1 ]]; then
  pass "AC-021: Script does NOT trigger image builds (no 'tutor images build' or 'docker build')"
else
  fail "AC-021: Script contains image build commands (should only update tags)"
fi

# Verify script modifies kustomization.yaml files
if grep -Eq "(kustomization\.yaml|newTag|setImage)" "$SCRIPT"; then
  pass "AC-021: Script modifies kustomization.yaml files with specified tags"
else
  fail "AC-021: Script missing kustomization.yaml update logic"
fi

# Check for @covers annotation
if grep -q "@covers.*AC-021" "$SCRIPT"; then
  pass "AC-021: Script has @covers AC-021 annotation"
else
  fail "AC-021: Script missing @covers AC-021 annotation"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
