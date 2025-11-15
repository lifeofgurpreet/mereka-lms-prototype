#!/usr/bin/env bash
# Fix service selector mismatches after pod restarts
# Usage: ./scripts/infra/fix-service-selectors.sh [namespace]
set -euo pipefail

NAMESPACE=${1:-mereka-lms}
SERVICES="lms cms caddy nginx discovery ecommerce notes xqueue"

echo "🔍 Checking service selectors in namespace: $NAMESPACE"
echo ""

for svc in $SERVICES; do
  echo "Checking $svc..."
  POD_INSTANCE=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=$svc -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}' 2>/dev/null || echo "")
  
  if [ -z "$POD_INSTANCE" ]; then
    echo "  ⚠️  No pods found for $svc, skipping"
    continue
  fi
  
  SVC_INSTANCE=$(kubectl get svc $svc -n "$NAMESPACE" -o jsonpath='{.spec.selector.app\.kubernetes\.io/instance}' 2>/dev/null || echo "")
  
  if [ -z "$SVC_INSTANCE" ]; then
    echo "  ⚠️  Service $svc not found, skipping"
    continue
  fi
  
  if [ "$POD_INSTANCE" != "$SVC_INSTANCE" ]; then
    echo "  🔧 Fixing selector: $SVC_INSTANCE -> $POD_INSTANCE"
    kubectl get svc $svc -n "$NAMESPACE" -o yaml > /tmp/${svc}-svc.yaml
    sed -i.bak "s/$SVC_INSTANCE/$POD_INSTANCE/g" /tmp/${svc}-svc.yaml
    kubectl apply -f /tmp/${svc}-svc.yaml && echo "  ✅ Fixed $svc"
    rm -f /tmp/${svc}-svc.yaml /tmp/${svc}-svc.yaml.bak
  else
    echo "  ✅ $svc selector matches"
  fi
done

echo ""
echo "📊 Verifying endpoints..."
kubectl get endpoints -n "$NAMESPACE" | grep -E "NAME|$SERVICES" || kubectl get endpoints -n "$NAMESPACE"

