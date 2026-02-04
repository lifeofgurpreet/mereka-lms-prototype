#!/usr/bin/env bash
# Verify Open edX monitoring setup
set -euo pipefail

echo "=== Open edX Monitoring Verification ==="
echo

echo "1. Checking ServiceMonitors..."
kubectl get servicemonitor -n mereka-lms
echo

echo "2. Checking PrometheusRules..."
kubectl get prometheusrule -n mereka-lms
echo

echo "3. Checking service endpoints..."
kubectl get endpoints -n mereka-lms lms cms
echo

echo "4. Testing LMS metrics endpoint (expected: 400 Bad Request until django-prometheus is installed)..."
if kubectl exec -n mereka-lms deploy/lms -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" localhost:8000/metrics 2>/dev/null; then
  echo "✓ LMS pod is reachable"
else
  echo "✗ LMS pod is not reachable"
fi
echo

echo "5. Testing CMS metrics endpoint (expected: 400 Bad Request until django-prometheus is installed)..."
if kubectl exec -n mereka-lms deploy/cms -- curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" localhost:8000/metrics 2>/dev/null; then
  echo "✓ CMS pod is reachable"
else
  echo "✗ CMS pod is not reachable"
fi
echo

echo "6. Checking if Prometheus Operator is running..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
echo

echo "7. Checking existing metrics (should show kubelet metrics)..."
echo "Sample query: container_memory_working_set_bytes for LMS"
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090 &
PF_PID=$!
sleep 3
if curl -s "http://localhost:9090/api/v1/query?query=container_memory_working_set_bytes{namespace='mereka-lms',pod=~'lms-.*'}" | jq -r '.status' 2>/dev/null; then
  echo "✓ Prometheus is accessible and returning metrics"
else
  echo "✗ Prometheus query failed (may need to wait for scrape)"
fi
kill $PF_PID 2>/dev/null || true
echo

echo "=== Summary ==="
echo "✓ ServiceMonitors created (but /metrics returns 400 - django-prometheus not installed)"
echo "✓ PrometheusRules created (using kubelet metrics)"
echo "✓ Services updated with named ports"
echo
echo "Next steps:"
echo "1. Enable django-prometheus in Open edX image (see IMPLEMENTATION_STATUS.md)"
echo "2. Port-forward to Prometheus UI: kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090"
echo "3. Check targets: http://localhost:9090/targets (search for 'lms-metrics')"
echo "4. Check alerts: http://localhost:9090/alerts"
