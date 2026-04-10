#!/usr/bin/env bash
# verify-middleware-divergence.sh — detect divergence between canonical middleware
# modules and bbi-infrastructure overlay copies.
#
# The overlay configMapGenerator includes copies of these Python modules.
# When the canonical version is updated, overlays must be synced.
# This gate fails if the files in the app repo don't match the overlay copies.
#
# @spec: multi-tenancy-architecture_spec.md
# @covers AC-MTA-017
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
INFRA_ROOT="${INFRA_ROOT_OVERRIDE:-${HOME}/projects/k8s/bbi-infrastructure}"

CANONICAL_DIR="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms"

# Modules that are copied to overlay configMapGenerators
MODULES=(
  mereka_multisite.py
  mereka_platform_admin.py
  mereka_forwarded_headers.py
  mereka_jwt_session.py
  mereka_enterprise_channels.py
  mereka_footer.py
)

OVERLAYS=(dev staging prod)

if [[ ! -d "${INFRA_ROOT}/apps/mereka-lms/overlays" ]]; then
  echo "SKIP: bbi-infrastructure not available at ${INFRA_ROOT}"
  exit 0
fi

failures=0

for module in "${MODULES[@]}"; do
  canonical="${CANONICAL_DIR}/${module}"
  if [[ ! -f "${canonical}" ]]; then
    echo "WARN: canonical ${module} not found at ${canonical}"
    continue
  fi

  for env in "${OVERLAYS[@]}"; do
    overlay="${INFRA_ROOT}/apps/mereka-lms/overlays/${env}/${module}"
    if [[ ! -f "${overlay}" ]]; then
      echo "WARN: overlay ${env}/${module} not found"
      continue
    fi

    if ! diff -q "${canonical}" "${overlay}" >/dev/null 2>&1; then
      echo "FAIL: ${module} diverged in ${env} overlay"
      diff --unified=3 "${canonical}" "${overlay}" | head -20
      failures=$((failures + 1))
    fi
  done
done

if [[ ${failures} -gt 0 ]]; then
  echo ""
  echo "FAIL: ${failures} middleware divergence(s) detected."
  echo "Sync overlays from canonical: deploy/k8s/base/apps/openedx/settings/lms/"
  exit 1
fi

echo "PASS: All middleware modules match between app repo and overlays."
