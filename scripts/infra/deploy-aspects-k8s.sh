#!/usr/bin/env bash
# Deploy Aspects Analytics to GKE Autopilot with appropriate resource limits
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

source infrastructure/tutor/tutor-env.sh

echo "=== Configuring Aspects for GKE Autopilot ==="
echo ""

# Configure Aspects with conservative resource limits for Autopilot
echo "Setting Aspects resource limits..."
tutor config save \
  --set ASPECTS_CLICKHOUSE_MEMORY_LIMIT=4Gi \
  --set ASPECTS_CLICKHOUSE_CPU_LIMIT=2 \
  --set ASPECTS_SUPERSET_MEMORY_LIMIT=2Gi \
  --set ASPECTS_SUPERSET_CPU_LIMIT=1 \
  --set ASPECTS_RALPH_MEMORY_LIMIT=512Mi \
  --set ASPECTS_RALPH_CPU_LIMIT=500m

echo ""
echo "=== Generating Kubernetes manifests ==="
tutor k8s init

echo ""
echo "=== Checking for Aspects manifests ==="
if find tutor_env/env/k8s -name "*clickhouse*" -o -name "*superset*" 2>/dev/null | grep -q .; then
  echo "Found Aspects manifests"
else
  echo "⚠️  No Aspects manifests found. Aspects may not be enabled for Kubernetes."
  echo "   Run: tutor plugins enable aspects && tutor config save"
  exit 1
fi

echo ""
echo "=== Deploying Aspects services ==="
echo ""

# Deploy ClickHouse
if kubectl get deployment clickhouse -n mereka-lms &>/dev/null; then
  echo "ClickHouse deployment exists, updating..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=clickhouse
else
  echo "Creating ClickHouse deployment..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=clickhouse
fi

# Deploy Superset
if kubectl get deployment superset -n mereka-lms &>/dev/null; then
  echo "Superset deployment exists, updating..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=superset
else
  echo "Creating Superset deployment..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=superset
fi

# Deploy Ralph (event routing)
if kubectl get deployment ralph -n mereka-lms &>/dev/null; then
  echo "Ralph deployment exists, updating..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=ralph
else
  echo "Creating Ralph deployment..."
  kubectl apply -k tutor_env/env/k8s --selector app.kubernetes.io/name=ralph
fi

echo ""
echo "=== Waiting for deployments ==="
kubectl wait --for=condition=available --timeout=300s \
  deployment/clickhouse -n mereka-lms || echo "⚠️  ClickHouse not ready yet"
kubectl wait --for=condition=available --timeout=300s \
  deployment/superset -n mereka-lms || echo "⚠️  Superset not ready yet"
kubectl wait --for=condition=available --timeout=300s \
  deployment/ralph -n mereka-lms || echo "⚠️  Ralph not ready yet"

echo ""
echo "=== Checking pod status ==="
kubectl get pods -n mereka-lms | grep -E "(clickhouse|superset|ralph)"

echo ""
echo "=== Checking for scheduling issues ==="
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | \
  grep -i -E "(clickhouse|superset|ralph|insufficient|failed)" | tail -10

echo ""
echo "=== Access Information ==="
echo ""
echo "To access Superset:"
echo "  kubectl port-forward -n mereka-lms svc/superset 8088:8088"
echo "  Then open: http://localhost:8088"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: Check with: tutor config printvalue SUPERSET_ADMIN_PASSWORD"
echo ""
echo "=== Done ==="





