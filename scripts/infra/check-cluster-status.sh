#!/usr/bin/env bash
# Check current cluster and Aspects status
set -euo pipefail

echo "=== Cluster Status Check ==="
echo ""

echo "--- Pods Status ---"
kubectl get pods -n mereka-lms | grep -E "(clickhouse|superset|ralph|mysql)" || echo "No Aspects pods found"
echo ""

echo "--- Services Status ---"
kubectl get svc -n mereka-lms | grep -E "(superset|clickhouse|mysql)" || echo "No Aspects services found"
echo ""

echo "--- Node Resources ---"
kubectl top nodes -n mereka-lms 2>/dev/null || echo "Metrics not available"
echo ""

echo "--- Recent Events (Aspects/MySQL) ---"
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | grep -E "(clickhouse|superset|ralph|mysql)" | tail -5 || echo "No recent events"
echo ""

echo "--- Superset Accessibility ---"
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8088 2>/dev/null | grep -q "200\|302\|401"; then
  echo "✅ Superset is accessible at http://localhost:8088"
else
  echo "⚠️  Superset not accessible locally. Port-forward may be needed:"
  echo "   kubectl port-forward -n mereka-lms svc/superset 8088:8088"
fi


