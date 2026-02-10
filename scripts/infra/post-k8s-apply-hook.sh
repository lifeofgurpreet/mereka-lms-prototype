#!/usr/bin/env bash
# Post-K8s-Apply Hook
# Automatically runs after kubectl apply/kustomize commands
# Verifies deployment health and fails if issues detected

set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "🔍 Running post-deployment verification..."

if [[ -x "$REPO_ROOT/scripts/infra/verify-deployment.sh" ]]; then
    "$REPO_ROOT/scripts/infra/verify-deployment.sh" "$NAMESPACE"
else
    echo "⚠️  Verification script not found, skipping"
fi
