#!/usr/bin/env bash
# Verify prometheus integration in Open edX deployment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Prometheus Integration Verification"
echo "===================================="
echo

# Check 1: Verify custom app files exist
echo "✓ Checking custom app files..."
REQUIRED_FILES=(
  "infrastructure/tutor/custom-apps/openedx_prometheus/__init__.py"
  "infrastructure/tutor/custom-apps/openedx_prometheus/apps.py"
  "infrastructure/tutor/custom-apps/openedx_prometheus/urls.py"
  "infrastructure/tutor/custom-apps/openedx_prometheus/setup.py"
  "infrastructure/tutor/custom-apps/openedx_prometheus/README.md"
)

for file in "${REQUIRED_FILES[@]}"; do
  if [ -f "$REPO_ROOT/$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ✗ $file NOT FOUND"
    exit 1
  fi
done
echo

# Check 2: Verify apply-patches.sh contains prometheus patches
echo "✓ Checking apply-patches.sh contains prometheus patches..."
PATCH_MARKERS=(
  "openedx_prometheus"
  "django-prometheus"
  "PrometheusBeforeMiddleware"
  "PrometheusAfterMiddleware"
  "location = /metrics"
)

for marker in "${PATCH_MARKERS[@]}"; do
  if grep -q "$marker" "$REPO_ROOT/infrastructure/tutor/apply-patches.sh"; then
    echo "  ✓ Found: $marker"
  else
    echo "  ✗ Missing: $marker"
    exit 1
  fi
done
echo

# Check 3: Verify documentation exists
echo "✓ Checking documentation..."
DOC_FILES=(
  "infrastructure/tutor/README.md"
  "infrastructure/tutor/custom-apps/openedx_prometheus/README.md"
  "PROMETHEUS_INTEGRATION.md"
)

for file in "${DOC_FILES[@]}"; do
  if [ -f "$REPO_ROOT/$file" ]; then
    echo "  ✓ $file"
  else
    echo "  ✗ $file NOT FOUND"
    exit 1
  fi
done
echo

# Check 4: Verify Python syntax
echo "✓ Checking Python syntax..."
python3 -c "
import ast
import sys

files = [
    '$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus/__init__.py',
    '$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus/apps.py',
    '$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus/urls.py',
    '$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus/setup.py',
]

for filepath in files:
    try:
        with open(filepath) as f:
            ast.parse(f.read())
        print(f'  ✓ {filepath.split(\"/\")[-1]}')
    except SyntaxError as e:
        print(f'  ✗ {filepath.split(\"/\")[-1]}: {e}')
        sys.exit(1)
"
echo

# Check 5: Verify bash syntax
echo "✓ Checking bash syntax..."
bash -n "$REPO_ROOT/infrastructure/tutor/apply-patches.sh" && echo "  ✓ apply-patches.sh"
echo

# Check 6: Test if in Kubernetes environment
if command -v kubectl &> /dev/null; then
  echo "✓ Kubernetes detected, checking ServiceMonitors..."

  if kubectl get namespace mereka-lms &> /dev/null; then
    echo "  ✓ Namespace mereka-lms exists"

    # Check if ServiceMonitors exist
    if kubectl get servicemonitor -n mereka-lms lms-metrics &> /dev/null; then
      echo "  ✓ ServiceMonitor lms-metrics exists"
    else
      echo "  ⚠ ServiceMonitor lms-metrics not found (expected if not deployed yet)"
    fi

    if kubectl get servicemonitor -n mereka-lms cms-metrics &> /dev/null; then
      echo "  ✓ ServiceMonitor cms-metrics exists"
    else
      echo "  ⚠ ServiceMonitor cms-metrics not found (expected if not deployed yet)"
    fi

    # Try to check if metrics endpoint is accessible (requires running pods)
    if kubectl get deployment lms -n mereka-lms &> /dev/null; then
      echo
      echo "  Testing /metrics endpoint (if pods are running)..."
      if kubectl exec -n mereka-lms deploy/lms -- curl -sf localhost:8000/metrics &> /dev/null; then
        echo "  ✓ /metrics endpoint is accessible and returning data"
        echo "  📊 Sample metrics:"
        kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics 2>/dev/null | head -5
      else
        echo "  ⚠ /metrics endpoint not accessible (expected if image not rebuilt yet)"
        echo "  ℹ  Rebuild Open edX image to activate metrics: tutor images build openedx"
      fi
    fi
  else
    echo "  ⚠ Namespace mereka-lms not found (expected in local dev)"
  fi
  echo
else
  echo "⚠ kubectl not found, skipping Kubernetes checks"
  echo
fi

# Summary
echo "=================================="
echo "✓ Verification Complete"
echo
echo "Implementation Status:"
echo "  ✓ Custom app created: openedx_prometheus"
echo "  ✓ Patches added to apply-patches.sh"
echo "  ✓ Documentation created"
echo "  ✓ Python syntax valid"
echo "  ✓ Bash syntax valid"
echo
echo "Next Steps:"
echo "  1. Apply patches: ./infrastructure/tutor/apply-patches.sh"
echo "  2. Rebuild image: tutor images build openedx (takes 30-45 min)"
echo "  3. Restart services: tutor local restart (or kubectl rollout restart)"
echo "  4. Test endpoint: curl http://localhost/metrics"
echo
echo "Documentation:"
echo "  - PROMETHEUS_INTEGRATION.md - Full implementation summary"
echo "  - infrastructure/tutor/README.md - Tutor configuration guide"
echo "  - infrastructure/tutor/custom-apps/openedx_prometheus/README.md - App docs"
