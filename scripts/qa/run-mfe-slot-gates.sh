#!/usr/bin/env bash
# @spec: mfe-plugin-slots_spec.md
# run-mfe-slot-gates.sh - consolidated gate for MFE plugin-slot contracts
# Defaults are non-mutating/static-safe.
# Opt-in runtime checks:
#   RUN_SLOT_RUNTIME=1
# Optional visual regression:
#   RUN_SLOT_VISUAL_REGRESSION=1 SLOT_VISUAL_ENV=prod|dev
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== MFE Slot Gate Bundle ==="
echo "RUN_SLOT_RUNTIME=${RUN_SLOT_RUNTIME:-0}"
echo "RUN_SLOT_VISUAL_REGRESSION=${RUN_SLOT_VISUAL_REGRESSION:-0}"

./scripts/qa/verify-mfe-plugin-slots.sh
./scripts/qa/verify-plugin-slot-wiring.sh

if [[ "${RUN_SLOT_RUNTIME:-0}" == "1" ]]; then
  echo "=== Runtime slot checks enabled ==="
  if [[ "${RUN_SLOT_RUNTIME_ALLOW_MUTATION:-0}" != "1" ]]; then
    echo "ERROR: RUN_SLOT_RUNTIME=1 requires RUN_SLOT_RUNTIME_ALLOW_MUTATION=1"
    echo "Refusing to run mutating slot persistence checks without explicit acknowledgement."
    exit 1
  fi
  for required_var in LMS_BASE_URL PROFILE_USERNAME API_TOKEN; do
    if [[ -z "${!required_var:-}" ]]; then
      echo "ERROR: RUN_SLOT_RUNTIME=1 requires ${required_var} to be set"
      exit 1
    fi
  done
  # Runtime mode for AC-SLOT-014 requires LMS_BASE_URL, PROFILE_USERNAME, API_TOKEN.
  CHECK_RUNTIME=1 ./scripts/qa/verify-mfe-slot-profile-persistence.sh
  CHECK_RUNTIME=1 ./scripts/qa/verify-mfe-slot-nfr.sh
else
  echo "=== Runtime slot checks disabled (default safe mode) ==="
  ./scripts/qa/verify-mfe-slot-profile-persistence.sh
  ./scripts/qa/verify-mfe-slot-nfr.sh
fi

./scripts/qa/verify-oep48-brand-package.sh
./scripts/qa/verify-branding-asset-sync.sh
./scripts/qa/verify-mfe-branding.sh

if [[ "${RUN_SLOT_VISUAL_REGRESSION:-0}" == "1" ]]; then
  echo "=== Optional slot visual regression enabled ==="
  ./scripts/qa/visual-regression-branding.sh "${SLOT_VISUAL_ENV:-prod}" --allow-bootstrap
fi

echo "=== MFE Slot Gate Bundle Complete ==="
