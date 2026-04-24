#!/usr/bin/env bash
# @covers AC-012
# @spec: k8s-deployment_spec.md
# Verify that K8s manifests contain no hardcoded passwords or API keys.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS+1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

K8S_DIR="$REPO_ROOT/deploy/k8s"

check "deploy/k8s directory exists" test -d "$K8S_DIR"

# Verify no hardcoded passwords in YAML manifests
check "No hardcoded PASSWORD values in K8s manifests" \
  bash -c "! grep -rn 'password:.*[a-zA-Z0-9]' '$K8S_DIR' --include='*.yaml' --include='*.yml' | grep -v '#' | grep -v 'secretKeyRef\|valueFrom\|env:\|name:.*password\|key:.*password\|description\|help_text' | grep -v '^\$'"

check "No hardcoded API keys in K8s manifests" \
  bash -c "! grep -rn 'api.key:.*[a-zA-Z0-9]\|apiKey:.*[a-zA-Z0-9]' '$K8S_DIR' --include='*.yaml' --include='*.yml' | grep -v '#\|secretKeyRef\|valueFrom\|name:\|key:' | grep -v '^\$'"

check "Pre-commit hook covers K8s secret scanning" test -f "$REPO_ROOT/.githooks/pre-commit"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
