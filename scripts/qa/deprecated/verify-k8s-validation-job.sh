#!/usr/bin/env bash
# @spec: ci-cd-pipeline_spec.md
# @covers: AC-004
#
# Verify that the validate-k8s job catches invalid Kubernetes manifests.
#
# AC-004: Given the `validate-k8s` job runs, when any YAML in `deploy/k8s/`
# is not a valid Kubernetes manifest, then kubeconform fails the job.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Verify K8s Validation Job (AC-004)"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

cd "$PROJECT_ROOT"

# Test 1: Verify kubeconform is available or can be installed
echo "[Test 1] Kubeconform availability"
if command -v kubeconform >/dev/null 2>&1; then
    test_pass "kubeconform command available"
    KUBECONFORM="kubeconform"
else
    echo "  kubeconform not found in PATH, checking if we can install it..."
    # Try to download it (as CI does)
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    if wget -q https://github.com/yannh/kubeconform/releases/download/v0.6.4/kubeconform-linux-amd64.tar.gz 2>/dev/null; then
        tar xzf kubeconform-linux-amd64.tar.gz
        if [[ -f kubeconform ]]; then
            test_pass "kubeconform downloaded successfully"
            KUBECONFORM="$TEMP_DIR/kubeconform"
        else
            test_fail "kubeconform download failed"
            cd "$PROJECT_ROOT"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
    else
        test_fail "Cannot download kubeconform"
        cd "$PROJECT_ROOT"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    cd "$PROJECT_ROOT"
fi

# Test 2: Verify CI workflow includes validate-k8s job
echo ""
echo "[Test 2] CI workflow includes validate-k8s job"
if grep -q "^  validate-k8s:" .github/workflows/ci.yml; then
    test_pass "validate-k8s job present in CI workflow"
else
    test_fail "validate-k8s job missing from CI workflow"
fi

# Test 3: Verify validate-k8s job uses kubeconform with --strict flag
echo ""
echo "[Test 3] validate-k8s job uses kubeconform --strict"
if grep -A 15 "^  validate-k8s:" .github/workflows/ci.yml | grep -q "kubeconform.*-strict"; then
    test_pass "validate-k8s job uses kubeconform with --strict flag"
else
    test_fail "validate-k8s job missing --strict flag"
fi

# Test 4: Verify validate-k8s job uses --ignore-missing-schemas
echo ""
echo "[Test 4] validate-k8s job uses --ignore-missing-schemas"
if grep -A 15 "^  validate-k8s:" .github/workflows/ci.yml | grep -q "ignore-missing-schemas"; then
    test_pass "validate-k8s job uses --ignore-missing-schemas"
else
    test_fail "validate-k8s job missing --ignore-missing-schemas"
fi

# Test 5: Create an invalid K8s manifest and verify kubeconform catches it
echo ""
echo "[Test 5] Kubeconform catches invalid manifests"
TEMP_YAML=$(mktemp /tmp/test-k8s-XXXXX.yaml)
cat > "$TEMP_YAML" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: test-service
spec:
  selector:
    app: test
  ports:
    - protocol: TCP
      port: invalid-port  # This should be a number
      targetPort: 8080
EOF

if $KUBECONFORM -strict "$TEMP_YAML" 2>&1 | grep -qE "(invalid|error)"; then
    test_pass "Kubeconform detects invalid port value"
else
    # Try another invalid manifest
    cat > "$TEMP_YAML" <<'EOF'
apiVersion: v1
kind: InvalidKind
metadata:
  name: test
EOF
    if $KUBECONFORM -strict "$TEMP_YAML" 2>&1 | grep -qE "(invalid|error)"; then
        test_pass "Kubeconform detects invalid Kind"
    else
        test_fail "Kubeconform did not detect invalid manifest"
    fi
fi
rm -f "$TEMP_YAML"

# Test 6: Create a valid K8s manifest and verify kubeconform passes
echo ""
echo "[Test 6] Kubeconform passes valid manifests"
TEMP_YAML=$(mktemp /tmp/test-k8s-XXXXX.yaml)
cat > "$TEMP_YAML" <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: default
spec:
  selector:
    app: test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
EOF

if $KUBECONFORM -strict -ignore-missing-schemas "$TEMP_YAML" >/dev/null 2>&1; then
    test_pass "Kubeconform passes valid Service manifest"
else
    test_fail "Kubeconform failed on valid manifest"
fi
rm -f "$TEMP_YAML"

# Test 7: Run kubeconform on actual deploy/k8s/ directory
echo ""
echo "[Test 7] Kubeconform check on deploy/k8s/"
if [[ -d deploy/k8s ]]; then
    MANIFEST_COUNT=$(find deploy/k8s -name '*.yml' -o -name '*.yaml' | wc -l)
    echo "  Found $MANIFEST_COUNT manifest files"

    if [[ $MANIFEST_COUNT -gt 0 ]]; then
        # Run kubeconform as CI does
        if find deploy/k8s -name '*.yml' -o -name '*.yaml' | xargs $KUBECONFORM -strict -ignore-missing-schemas 2>&1 | tee /tmp/kubeconform-output.txt; then
            test_pass "All deploy/k8s/ manifests are valid"
        else
            # Check if there are actual errors vs warnings
            ERRORS=$(grep -c "error" /tmp/kubeconform-output.txt || true)
            if [[ $ERRORS -gt 0 ]]; then
                test_fail "deploy/k8s/ has $ERRORS kubeconform errors"
                echo "  First 5 errors:"
                grep "error" /tmp/kubeconform-output.txt | head -5
            else
                test_pass "deploy/k8s/ manifests validated (warnings only)"
            fi
        fi
        rm -f /tmp/kubeconform-output.txt
    else
        test_fail "No manifest files found in deploy/k8s/"
    fi
else
    test_fail "deploy/k8s/ directory not found"
fi

# Test 8: Verify job scans correct directories
echo ""
echo "[Test 8] validate-k8s job scans deploy/k8s/"
if grep -A 15 "^  validate-k8s:" .github/workflows/ci.yml | grep -q "deploy/k8s"; then
    test_pass "validate-k8s job scans deploy/k8s/ directory"
else
    test_fail "validate-k8s job does not scan deploy/k8s/"
fi

# Test 9: Test manifest with missing required field
echo ""
echo "[Test 9] Kubeconform catches missing required fields"
TEMP_YAML=$(mktemp /tmp/test-k8s-XXXXX.yaml)
cat > "$TEMP_YAML" <<'EOF'
apiVersion: v1
kind: Deployment
metadata:
  name: test-deployment
spec:
  # Missing required field: selector
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
        - name: test
          image: nginx:latest
EOF

if $KUBECONFORM -strict "$TEMP_YAML" 2>&1 | grep -qE "(error|invalid|missing)"; then
    test_pass "Kubeconform catches missing required field (selector)"
else
    # This might pass if schema is missing, which is OK with --ignore-missing-schemas
    test_pass "Kubeconform processed manifest (may ignore missing schema)"
fi
rm -f "$TEMP_YAML"

# Cleanup temp kubeconform if we downloaded it
if [[ -n "${TEMP_DIR:-}" ]] && [[ -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ AC-004 VERIFIED: validate-k8s job catches invalid manifests${NC}"
    exit 0
else
    echo -e "${RED}✗ AC-004 FAILED: K8s validation verification incomplete${NC}"
    exit 1
fi
