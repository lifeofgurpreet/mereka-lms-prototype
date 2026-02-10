#!/usr/bin/env bash
# Post-deployment verification script
# Checks pods, logs, secrets, and endpoints after K8s deployments

set -euo pipefail

NAMESPACE="${1:-mereka-lms}"
VERBOSE="${VERBOSE:-0}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

ERRORS=0

echo "==> Verifying deployment in namespace: $NAMESPACE"

# 1. Check pod status
echo ""
echo "==> Checking pod status..."
FAILING_PODS=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running,status.phase!=Succeeded -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.containerStatuses[*].state..reason}{"\n"}{end}' 2>/dev/null || true)

if [ -n "$FAILING_PODS" ]; then
    log_error "Found failing pods:"
    echo "$FAILING_PODS" | while IFS=$'\t' read -r name phase reason; do
        echo "  - $name: $phase ($reason)"
        if [[ "$reason" == *"ConfigError"* ]] || [[ "$reason" == *"Error"* ]]; then
            echo "    Error details:"
            kubectl describe pod "$name" -n "$NAMESPACE" 2>/dev/null | grep -A 5 "Error:" | sed 's/^/      /'
        fi
    done
    ((ERRORS++))
else
    log_success "All pods running"
fi

# 2. Check deployment readiness
echo ""
echo "==> Checking deployments..."
NOT_READY=$(kubectl get deployments -n "$NAMESPACE" -o json | jq -r '.items[] | select(.status.readyReplicas != .status.replicas) | "\(.metadata.name): \(.status.readyReplicas // 0)/\(.status.replicas)"' 2>/dev/null || true)

if [ -n "$NOT_READY" ]; then
    log_error "Deployments not ready:"
    echo "$NOT_READY" | sed 's/^/  /'
    ((ERRORS++))
else
    log_success "All deployments ready"
fi

# 3. Check for recent errors in logs
echo ""
echo "==> Checking recent logs for errors..."
for deployment in lms cms mfe; do
    ERROR_LOGS=$(kubectl logs -n "$NAMESPACE" -l "app.kubernetes.io/name=$deployment" --since=5m --tail=100 2>/dev/null | grep -i "error\|exception\|failed" | head -5 || true)
    if [ -n "$ERROR_LOGS" ]; then
        log_warn "Found errors in $deployment logs:"
        echo "$ERROR_LOGS" | sed 's/^/  /'
    fi
done

# 4. Verify critical secrets exist
echo ""
echo "==> Verifying secrets..."
REQUIRED_SECRETS=("openedx-secrets")
for secret in "${REQUIRED_SECRETS[@]}"; do
    if kubectl get secret "$secret" -n "$NAMESPACE" &>/dev/null; then
        # Check specific keys
        MISSING_KEYS=$(kubectl get secret "$secret" -n "$NAMESPACE" -o json | jq -r '
            ["OPENEDX_SECRET_KEY", "MONGODB_PASSWORD", "MEILISEARCH_MASTER_KEY"] as $required |
            .data | keys as $actual |
            $required - $actual | .[]
        ' 2>/dev/null || true)

        if [ -n "$MISSING_KEYS" ]; then
            log_error "Secret $secret missing keys: $MISSING_KEYS"
            ((ERRORS++))
        else
            log_success "Secret $secret has all required keys"
        fi
    else
        log_error "Secret $secret not found"
        ((ERRORS++))
    fi
done

# 5. Test endpoints
echo ""
echo "==> Testing endpoints..."
ENDPOINTS=("https://academyv2.mereka.io" "https://apps.academyv2.mereka.io/discussions")
for endpoint in "${ENDPOINTS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "$endpoint" || echo "000")
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
        log_success "$endpoint → HTTP $HTTP_CODE"
    else
        log_error "$endpoint → HTTP $HTTP_CODE"
        ((ERRORS++))
    fi
done

# 6. Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    log_success "Deployment verification PASSED"
    exit 0
else
    log_error "Deployment verification FAILED with $ERRORS error(s)"
    exit 1
fi
