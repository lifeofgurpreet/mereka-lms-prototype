#!/usr/bin/env bash
# Rapid recovery for staging routing outages caused by selector drift or missing HTTPS port on caddy
# Usage: ./scripts/infra/repair-staging-routing.sh [namespace]
set -euo pipefail

NAMESPACE=${1:-mereka-lms}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: $1 is required" >&2
    exit 1
  fi
}

require_cmd kubectl

ensure_caddy_https_port() {
  log "Checking caddy service ports in namespace: $NAMESPACE"
  local port_lines
  port_lines=$(kubectl get svc caddy -n "$NAMESPACE" -o jsonpath='{range .spec.ports[*]}{.port}:{.targetPort}:{.name}{"\n"}{end}' 2>/dev/null || true)

  if [[ -z "$port_lines" ]]; then
    log "WARNING: caddy service not found in namespace $NAMESPACE"
    return
  fi

  if echo "$port_lines" | grep -q '^443:443:'; then
    log "HTTPS port already present on caddy service"
    return
  fi

  log "Adding HTTPS (443) to caddy service"
  kubectl patch svc caddy -n "$NAMESPACE" --type='json' \
    -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "https", "port": 443, "protocol": "TCP", "targetPort": 443}}]'
}

verify_endpoints() {
  log "Verifying endpoints for caddy, lms, cms"
  kubectl get endpoints -n "$NAMESPACE" caddy cms lms
}

log "Running selector repair"
"$SCRIPT_DIR"/fix-service-selectors.sh "$NAMESPACE"

ensure_caddy_https_port

verify_endpoints

LB_IP=$(kubectl get svc caddy -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -n "$LB_IP" ]]; then
  log "Current caddy LoadBalancer IP: $LB_IP"
fi

cat <<EOF

Next steps:
1) Wait 5-15 minutes for GCP LoadBalancer to propagate port 443 if it was just added.
2) Test HTTPS externally:
   curl -Ik https://academyv2.mereka.io
   curl -Ik https://${LB_IP:-<caddy-lb-ip>}
3) If endpoints are empty again after a rollout, rerun this script.
EOF
