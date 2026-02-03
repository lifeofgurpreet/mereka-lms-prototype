#!/usr/bin/env bash
# Force ArgoCD refresh for apps using remote bases
set -euo pipefail

NAMESPACE="${ARGO_NAMESPACE:-argocd}"
REFRESH_TYPE="${ARGO_REFRESH_TYPE:-hard}"
TIMESTAMP="$(date +%s)"

apps=()
if [[ $# -gt 0 ]]; then
  apps=("$@")
elif [[ -n "${ARGO_APPS:-}" ]]; then
  read -r -a apps <<< "$ARGO_APPS"
fi

if [[ ${#apps[@]} -eq 0 ]]; then
  echo "Usage: $0 <app1> [app2 ...]" >&2
  echo "Or set ARGO_APPS=\"app1 app2\"." >&2
  exit 1
fi

for app in "${apps[@]}"; do
  printf "Refreshing %s in %s (type=%s)\n" "$app" "$NAMESPACE" "$REFRESH_TYPE"
  kubectl annotate application "$app" -n "$NAMESPACE" \
    "argocd.argoproj.io/refresh=${REFRESH_TYPE}" \
    "mereka.io/refresh-ts=${TIMESTAMP}" \
    --overwrite
  echo "✓ Refresh annotation applied to $app"
done
