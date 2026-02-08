#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Checking Open edX production overlays for mutable 'latest' tags..."

violations=0

while IFS= read -r kustomization_file; do
  if rg -n '^[[:space:]]*newTag:[[:space:]]*["'"'"']?latest["'"'"']?([[:space:]]*#.*)?$' "$kustomization_file" >/tmp/mereka-prod-latest-hits.txt; then
    echo "❌ latest newTag found in ${kustomization_file#"$REPO_ROOT"/}:"
    sed 's/^/  /' /tmp/mereka-prod-latest-hits.txt
    violations=1
  fi
done < <(find "$REPO_ROOT/deploy/k8s/overlays" -type f -name kustomization.yaml \( -path '*/prod/*' -o -path '*/production/*' \) | sort)

rm -f /tmp/mereka-prod-latest-hits.txt

if [[ "$violations" -ne 0 ]]; then
  echo "Production tag policy failed."
  exit 1
fi

echo "✅ Production tag policy passed (no mutable 'latest' tags)."
